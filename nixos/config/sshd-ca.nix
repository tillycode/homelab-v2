{
  # To provision sshd CA
  #
  #   bao secrets enable -path=ssh-client-signer ssh
  #   bao write ssh-client-signer/config/ca generate_signing_key=true key_type=ssh-ed25519
  #   bao secrets enable -path=ssh-host-signer ssh
  #   bao write ssh-host-signer/config/ca generate_signing_key=true key_type=ssh-ed25519
  #   bao secrets tune -max-lease-ttl=87600h ssh-host-signer
  #   bao write ssh-host-signer/roles/hostrole \
  #     key_type=ca \
  #     ttl=87600h \
  #     allow_host_certificates=true \
  #     allowed_domains="nodes.szp15.com" \
  #     allow_subdomains=true
  #
  #  Deploy this profile to every host, then run
  #
  #   host=router.nodes.szp15.com
  #   bao write -field=signed_key ssh-host-signer/sign/hostrole cert_type=host \
  #     valid_principals="$host" public_key="$(ssh-keyscan -q -t rsa "$host" | cut -d" " -f2-)" |
  #     ssh -T -e none "root@$host" "cat > /etc/ssh/ssh_host_rsa_key-cert.pub"
  #   bao write -field=signed_key ssh-host-signer/sign/hostrole cert_type=host \
  #     valid_principals="$host" public_key="$(ssh-keyscan -q -t ed25519 "$host" | cut -d" " -f2-)" |
  #     ssh -T -e none "root@$host" "cat > /etc/ssh/ssh_host_ed25519_key-cert.pub"
  #   ssh "root@$host" systemctl reload sshd
  services.openssh.extraConfig = ''
    TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys
    HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
    HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
  '';
  programs.ssh.knownHosts.szp15-com = {
    certAuthority = true;
    extraHostNames = [ "*.nodes.szp15.com" ];
    # curl https://openbao.szp15.com/v1/ssh-host-signer/public_key
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMp/VRiJ22pvPv8mrChmweC4Q1peeO8v5lMiAEoHTQ2S";
  };
  # curl https://openbao.szp15.com/v1/ssh-client-signer/public_key
  environment.etc."ssh/trusted-user-ca-keys".text = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF0y07dXWvTx+D/DgRDaAr+4AMOuHX7PWnrWwGiq3CYG
  '';
  preservation.preserveAt.default.files = [
    {
      file = "/etc/ssh/ssh_host_rsa_key-cert.pub";
      how = "symlink";
      configureParent = true;
    }
    {
      file = "/etc/ssh/ssh_host_ed25519_key-cert.pub";
      how = "symlink";
      configureParent = true;
    }
  ];
}
