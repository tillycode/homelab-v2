{ config, lib, ... }:
let
  inherit (config.system) name;
in
{
  imports = [ ./_disko-impl.nix ];
  config = lib.mkMerge [
    (lib.mkIf (lib.match "hasee[[:digit:]]+" name != null) {
      profiles.system.disko = {
        devices = [
          "/dev/disk/by-path/pci-0000:01:00.0-nvme-1"
        ];
        swapSize = "32G";
      };
    })

    (lib.mkIf (name == "hgh0") {
      profiles.system.disko = {
        devices = [ "/dev/vda" ];
        swapSize = "16G";
      };
    })

    (lib.mkIf (name == "router") {
      profiles.system.disko = {
        devices = [ "/dev/disk/by-path/pci-0000:05:00.0-nvme-1" ];
        swapSize = "8G";
      };
    })

    (lib.mkIf (name == "sjc1") {
      profiles.system.disko = {
        devices = [ "/dev/sda" ];
        swapSize = "1G";
        legacyBoot = true;
      };
    })

    (lib.mkIf (name == "laptop") {
      profiles.system.disko = {
        devices = [ "/dev/disk/by-path/pci-0000:55:00.0-nvme-1" ];
        swapSize = "32G";
      };
    })

    (lib.mkIf (name == "lax0" || name == "hkg1") {
      profiles.system.disko = {
        devices = [ "/dev/vda" ];
        swapSize = "1G";
        legacyBoot = true;
      };
    })
    (lib.mkIf (name == "hkg0") {
      profiles.system.disko = {
        devices = [ "/dev/sda" ];
        swapSize = "2G";
        legacyBoot = true;
      };
    })
  ];
}
