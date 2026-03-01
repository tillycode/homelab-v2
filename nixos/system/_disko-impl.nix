{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.profiles.system.disko;
  rootContent = {
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
in
{
  options.profiles.system.disko = {
    devices = lib.mkOption {
      type = lib.types.listOf lib.types.externalPath;
      description = "Full paths to the devices";
    };
    swapSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Size of the swap file";
    };
    tmpfsSize = lib.mkOption {
      type = lib.types.str;
      default = "50%";
      description = "Size of the root tmpfs";
    };
    enableLVM = lib.mkEnableOption "LVM";
    lvmRootSize = lib.mkOption {
      type = lib.types.str;
      description = "Size of the root logical volume";
    };
    lvmRootType = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Type of the root logical volume";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.devices != [ ];
          message = "devices is required";
        }
        {
          assertion = !cfg.enableLVM -> lib.length cfg.devices == 1;
          message = "devices must be single when LVM is not used";
        }
      ];

      disko.devices = {
        disk.main = {
          type = "disk";
          device = lib.head cfg.devices;
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
              };
            };
          };
        };
        nodev."/" = {
          fsType = "tmpfs";
          mountOptions = [
            "defaults"
            "size=${cfg.tmpfsSize}"
            "mode=755"
          ];
        };
      };

      fileSystems."/.persist".neededForBoot = true;
      preservation.preserveAt.default.persistentStoragePath = "/.persist";
    }

    (lib.mkIf (!cfg.enableLVM) {
      disko.devices.disk.main.content.partitions.primary.content = rootContent;
    })

    (lib.mkIf (!cfg.enableLVM && cfg.swapSize != null) {
      disko.devices.disk.main.content.partitions.primary.content.subvolumes = {
        "@swap" = {
          mountpoint = "/.swap";
          swap.swapfile.size = cfg.swapSize;
        };
      };
    })

    (lib.mkIf cfg.enableLVM {
      disko.devices = {
        disk = {
          main.content.partitions.primary.content = {
            type = "lvm_pv";
            vg = "pool";
          };
        }
        // lib.listToAttrs (
          lib.imap1 (i: device: {
            name = "data${toString i}";
            value = {
              type = "disk";
              device = device;
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
          }) (lib.tail cfg.devices)
        );

        lvm_vg.pool = {
          type = "lvm_vg";
          lvs = {
            root = {
              size = cfg.lvmRootSize;
              lvm_type = cfg.lvmRootType;
              content = rootContent;
            };
          };
        };
      };

      # FIXME: LVM uses udev rules and systemd-run to activate the pool.
      # However, activation may fail due to running before kernel modules are loaded.
      # See https://github.com/NixOS/nixpkgs/issues/428775.
      # Patch the udev rules, and manually setup LVM in initrd.
      boot.initrd.services.lvm.enable = false;
      boot.initrd.services.udev.packages =
        let
          lvmUdevRules =
            pkgs.runCommandLocal "lvm-udev-rules"
              {
                inherit (config.services.lvm) package;
              }
              ''
                mkdir -p $out/lib/udev/rules.d
                cp ''$package/lib/udev/rules.d/*.rules $out/lib/udev/rules.d
                substituteInPlace $out/lib/udev/rules.d/69-dm-lvm.rules \
                  --replace-fail "systemd-run --no-block " \
                  "systemd-run --no-block --property=After=systemd-modules-load.service "
              '';
        in
        [ lvmUdevRules ];
      boot.initrd.systemd.initrdBin = [ config.services.lvm.package ];
      boot.initrd.services.udev.binPackages = [ config.services.lvm.package ];
    })

    (lib.mkIf (cfg.enableLVM && cfg.swapSize != null) {
      disko.devices.lvm_vg.pool.lvs.swap = {
        size = cfg.swapSize;
        content = {
          type = "swap";
          resumeDevice = true;
        };
      };
    })

  ];
}
