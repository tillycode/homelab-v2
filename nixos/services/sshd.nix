{
  services.openssh.enable = true;
  services.openssh.settings.X11Forwarding = true;
  services.openssh.extraConfig = ''
    ClientAliveInterval 60
    ClientAliveCountMax 2
    StreamLocalBindUnlink yes
  '';

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAamaMcCAc7DhTJjDqBwXTWhewX0OI8vAuXLvc17yqK/ cardno:19_795_283"
  ];

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
