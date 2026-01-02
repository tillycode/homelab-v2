{
  lib,
  config,
  pkgs,
  ...
}:
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

  preservation.preserveAt.default.persistentStoragePath = "/.persist";

  virtualisation.vmVariantWithDisko = {
    disko.devices.disk.main.content.partitions.ESP.size = lib.mkForce "100M";
    disko.devices.lvm_vg.pool.lvs.root.size = lib.mkForce "1G";
    disko.devices.lvm_vg.pool.lvs.swap.size = lib.mkForce "1G";
    disko.devices.lvm_vg.pool.lvs.ceph.size = lib.mkForce "1G";
  };

  # FIXME: LVM uses udev rules and systemd-run to activate the pool.
  # However, activation may fail due to running before kernel modules are loaded.
  # See https://github.com/NixOS/nixpkgs/issues/428775.
  # Patch the udev rules, and manually setup LVM in initrd.
  boot.initrd.services.lvm.enable = false;
  boot.initrd.services.udev.packages =
    let
      pkg =
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
    [ pkg ];
  boot.initrd.systemd.initrdBin = [ config.services.lvm.package ];
  boot.initrd.services.udev.binPackages = [ config.services.lvm.package ];
}
