let
  mkBtrfsMount = subvol: {
    device = "/dev/disk/by-partlabel/nixos";
    fsType = "btrfs";
    options = [
      "subvol=@${subvol}"
      "noatime"
      "compress-force=zstd"
      "discard=async"
    ];
  };
in
{
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=16G"
      "mode=755"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/EFI";
    fsType = "vfat";
  };

  fileSystems."/nix" = mkBtrfsMount "nix";
  fileSystems."/persist" = mkBtrfsMount "persist" // {
    neededForBoot = true;
  };
  fileSystems."/swap" = mkBtrfsMount "swap";

  preservation.preserveAt.default.persistentStoragePath = "/persist";

  sops.age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
  sops.gnupg.sshKeyPaths = [ ];

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 32 * 1024;
    }
  ];
  boot.kernelParams = [ "resume_offset=533760" ];
  boot.resumeDevice = "/dev/disk/by-partlabel/nixos";
}
