## SOP

> [!CAUTION]
> The private key is generated in plaintext and distributed to each node.

### Bootstrap

1.  Generate the private key:

    ```shell
    # From the admin machine
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out rsa2048.pem
    ```

2.  For each node, copy the key, import it into the TPM, then securely delete the copy:

    ```shell
    # From the admin machine
    scp rsa2048.pem <node>:~/rsa2048.pem

    # On each node
    tpm2 clear
    pkcs11-tool --slot-index=0 --init-token --label=OpenBao
    pkcs11-tool --slot-index=0 --init-pin --login
    read -r -s -p "PIN: " USER_PIN
    tpm2_ptool import --label OpenBao --key-label bao-unseal-01 --privkey rsa2048.pem --algorithm rsa --userpin "$USER_PIN"
    shred -u rsa2048.pem
    ```

3.  delete the private key from the admin machine and initialise the cluster:

    ```shell
    # From the admin machine
    shred -u rsa2048.pem
    kubectl exec -it openbao-0 -n openbao -- bao operator init -recovery-shares=1 -recovery-threshold=1 --tls-skip-verify
    ```

### Rotate the Private Key

1.  Follow steps 1–2 of [Bootstrap](#bootstrap) to generate and import a new key on every node. DO NOT RUN `tpm2 clear`.

2.  Update `key_label` in the seal configuration (`values.yaml`) and roll out the change.
    OpenBao will re-encrypt its wrapping key with the new key.

3.  Once all nodes have restarted with the new key, delete the old key from each node's TPM:

    ```shell
    # On each node
    pkcs11-tool --delete-object --type privkey --label bao-unseal-01 --login
    ```

### One TPM Fails

Once the private key is deleted after being imported into TPM.
You can no long export the key.
To deal with a TPM failure or reset, the key must be rotated.

1.  Follow steps 1–2 of [Bootstrap](#bootstrap) to generate and import a **new** private key on all healthy nodes and the replacement node.

2.  Clean up the PV of the affected node so it joins as a fresh Raft member (otherwise it will attempt to decrypt existing data and fail):

3.  Update the seal configuration and roll out the change. The replacement pod will replicate existing data from the healthy nodes.
