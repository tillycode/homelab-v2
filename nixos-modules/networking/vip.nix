{ lib, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  options.networking.vip = mkOption {
    type = types.listOf types.str;
    default = [ ];
    description = "Address to be added to the dummy interface";
  };

  config = lib.mkIf (config.networking.vip != [ ]) {
    systemd.network.netdevs."40-vip" = {
      netdevConfig = {
        Kind = "dummy";
        Name = "vip";
      };
    };

    systemd.network.networks."40-vip" = {
      matchConfig.Name = "vip";
      address = config.networking.vip;
      networkConfig.LinkLocalAddressing = "no";
    };
  };
}
