{
  services.openssh.enable = true;
  services.openssh.settings.X11Forwarding = true;
  services.openssh.extraConfig = ''
    ClientAliveInterval 60
    ClientAliveCountMax 2
    StreamLocalBindUnlink yes
    TrustedUserCAKeys /etc/ssh/trusted-user-ca-key
  '';

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAamaMcCAc7DhTJjDqBwXTWhewX0OI8vAuXLvc17yqK/ cardno:19_795_283"
  ];

  # can be get from https://vault.szp15.com/v1/ssh-client-signer/public_key
  environment.etc."ssh/trusted-user-ca-key".text = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFVZ+OFf9rOa7f0ofNymsuzXa5vjVO+PQbyS6LBF3xFV
  '';

  preservation.preserveAt.default.files = [
    {
      file = "/etc/ssh/ssh_host_rsa_key";
      how = "symlink";
      configureParent = true;
    }
    {
      file = "/etc/ssh/ssh_host_ed25519_key";
      how = "symlink";
      configureParent = true;
    }
  ];
}
