{ lib, config, ... }:
let
  cfg = config.profiles.disko;
in
{
  options.profiles.disko = {
    enable = lib.mkEnableOption "Enable single-disk disko profile";
    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Full path to the device";
    };
    swapSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Size of the swap file";
    };
    tmpfsSize = lib.mkOption {
      type = lib.types.str;
      default = "50%";
      description = "Size of the root tmpfs";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.device != null;
        message = "device is required";
      }
    ];

    disko.devices = {
      disk.main = {
        type = "disk";
        device = cfg.device;
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
                }
                // lib.optionalAttrs (cfg.swapSize != null) {
                  "@swap" = {
                    mountpoint = "/.swap";
                    swap.swapfile.size = cfg.swapSize;
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
          "size=${cfg.tmpfsSize}"
          "mode=755"
        ];
      };
    };

    fileSystems."/.persist".neededForBoot = true;
    preservation.preserveAt.default.persistentStoragePath = "/.persist";
  };
}
