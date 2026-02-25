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

  config.systemd.network.networks."40-loopback" =
    lib.mkIf (config.networking.loopback.address != [ ])
      {
        matchConfig.Name = "lo";
        address = config.networking.loopback.address;
      };
}
