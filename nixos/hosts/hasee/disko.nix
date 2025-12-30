{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:02:00.0-nvme-1";
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
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };
    disk.data1 = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:01:00.0-nvme-1";
      content = {
        type = "gpt";
        partitions = {
          primary = {
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };

    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        root = {
          size = "512G";
          lvm_type = "raid0";
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
            };
          };
        };
        ceph = {
          size = "512G";
          lvm_type = "raid0";
        };
        swap = {
          size = "32G";
          content = {
            type = "swap";
            resumeDevice = true;
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
}
