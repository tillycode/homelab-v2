{
  system.nixos-init.enable = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.emergencyAccess = true;
  system.etc.overlay.enable = true;

  services.userborn.enable = true;
  services.userborn.passwordFilesLocation = "/var/lib/nixos";
  # We need to preserve /var/lib/userborn if mutableUsers is true.
  # Otherwise, userborn cannot distinguish declarative users from imperative ones.
  users.mutableUsers = false;

  preservation.preserveAt.default.directories = [
    "/var/lib/nixos"
  ];
}
