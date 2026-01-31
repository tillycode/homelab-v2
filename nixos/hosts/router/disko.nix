{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:05:00.0-nvme-1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          primary = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress-force=zstd"
                    "noatime"
                  ];
                };
                "@persist" = {
                  mountpoint = "/.persist";
                  mountOptions = [ "compress-force=zstd" ];
                };
                "@swap" = {
                  mountpoint = "/.swap";
                  swap.swapfile.size = "8G";
                };
              };
            };
          };
        };
      };
    };
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=50%"
        "mode=755"
      ];
    };
  };

  fileSystems."/.persist".neededForBoot = true;

  preservation.preserveAt.default.persistentStoragePath = "/.persist";
}
