{ lib, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  options.networking.loopback = {
    address = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra address to be added to the loopback interface";
    };
  };

  options.networking.vip = {
    address = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Address to be added to the dummy interface";
    };
  };

  config.systemd.network.networks."40-loopback" =
    lib.mkIf (config.networking.loopback.address != [ ])
      {
        matchConfig.Name = "lo";
        address = config.networking.loopback.address;
      };

  config.systemd.network.netdevs."40-vip" = lib.mkIf (config.networking.vip.address != [ ]) {
    netdevConfig = {
      Kind = "dummy";
      Name = "vip";
    };
  };

  config.systemd.network.networks."40-vip" = lib.mkIf (config.networking.vip.address != [ ]) {
    matchConfig.Name = "vip";
    address = config.networking.vip.address;
    networkConfig.LinkLocalAddressing = "no";
  };
}
