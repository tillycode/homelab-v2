{
  # To provision root CA
  #
  #   ykman piv reset
  #   ykman piv access change-pin
  #   ykman piv access change-puk
  #   ykman piv access change-management-key --algorithm AES256 --generate --protect --touch
  #   ykman piv keys generate --algorithm ECCP384 --pin-policy ALWAYS --touch-policy ALWAYS 9c root-a.pub.pem
  #   ykman piv keys attest 9c root-a.attestation.crt
  #   # 2 pin entries, 1 touch, 1 pin entry, then 1 touch
  #   step certificate create --profile root-ca --key 'yubikey:slot-id=9c?pin-prompt=true' --not-after 87600h "Ziping Sun Root CA" root-a.crt
  #   ykman piv certificates import --verify 9c root-a.crt
  #
  # To provision intermediate CA
  #
  #   tpm2pkcs11-tool --slot-index=1 --init-token --label=OpenBaoExternalKeys
  #   tpm2pkcs11-tool --token-label=OpenBaoExternalKeys --init-pin --login
  #   tpm2pkcs11-tool --token-label=OpenBaoExternalKeys --keypairgen --login --label pki-int --key-type EC:secp384r1
  #   # may need to restart openbao to refresh the cache
  #   bao write sys/external-keys/configs/tpm2 plugin=pkcs11 lib=tpm2 token_label=OpenBaoExternalKeys pin=... verify=true
  #   bao write sys/external-keys/configs/tpm2/keys/pki-int label=pki-int verify=true
  #   bao write -f sys/external-keys/configs/tpm2/keys/pki-int/grants/pki
  #
  #   bao secrets enable -path=pki pki
  #   bao secrets tune -max-lease-ttl=26280h pki
  #   bao write pki/config/cluster \
  #     path="https://openbao.szp15.com/v1/pki" \
  #     aia_path="https://openbao.szp15.com/v1/pki"
  #   bao write pki/config/urls \
  #     enable_templating=true \
  #     issuing_certificates="{{cluster_aia_path}}/issuer/{{issuer_id}}/der" \
  #     crl_distribution_points="{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der" \
  #     delta_crl_distribution_points="{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/delta/der" \
  #     ocsp_servers="{{cluster_aia_path}}/ocsp"
  #   bao write -format=json pki/intermediate/generate/kms \
  #     common_name="Ziping Sun Intermediate CA" external_key_ref=tpm2:pki-int |
  #     jq -r '.data.csr' > pki-int.csr
  #   # 2 pin entries, then 1 touch
  #   step certificate sign --profile intermediate-ca --not-after 26280h pki-int.csr root-a.crt 'yubikey:slot-id=9c?pin-prompt=true' > pki-int.crt
  #   bao write /pki/intermediate/set-signed certificate=@pki-int.crt
  #
  #   bao write pki/config/crl auto_rebuild=true enable_delta=true
  #   bao write pki/config/auto-tidy \
  #     enabled=true \
  #     tidy_cert_store=true \
  #     tidy_revoked_certs=true \
  #     tidy_acme=true
  #
  #
  # To enable ACME
  #
  #   bao secrets tune \
  #     -allowed-response-headers=Replay-Nonce \
  #     -allowed-response-headers=Link \
  #     -allowed-response-headers=Location pki/
  #   bao write pki/config/acme enabled=true eab_policy=always-required
  security.pki.certificateFiles = [
    ./ca.crt
  ];
}
