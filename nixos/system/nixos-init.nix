{
  system.nixos-init.enable = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.emergencyAccess = true;
  system.etc.overlay.enable = true;
  services.userborn.enable = true;
}
