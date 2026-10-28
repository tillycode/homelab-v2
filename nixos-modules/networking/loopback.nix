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

  options.networking.dummy = {
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

  config.systemd.network.netdevs."40-dummy" = lib.mkIf (config.networking.dummy.address != [ ]) {
    netdevConfig = {
      Kind = "dummy";
      Name = "dummy0";
    };
  };

  config.systemd.network.networks."40-dummy" = lib.mkIf (config.networking.dummy.address != [ ]) {
    matchConfig.Name = "dummy0";
    address = config.networking.dummy.address;
    networkConfig.LinkLocalAddressing = "no";
  };
}
