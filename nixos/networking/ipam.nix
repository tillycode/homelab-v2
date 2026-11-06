{ config, ... }:
let
  inherit (config.system) name;
  index = {
    router = 1;
    hasee01 = 2;
    hasee02 = 3;
    hasee03 = 4;
    desktop = 5;
    hgh0 = 6;
    sjc1 = 7;
    lax0 = 8;
    hkg0 = 9;
    hkg1 = 10;
    laptop = 11;
  };
in
{
  networking = {
    index = index.${name};
    ipam = {
      enable = true;
      ipv4Pool = "10.112.8.0/24";
      ipv6Pool = "fdfe:3c59:ba97::/64";
    };
  };
}
