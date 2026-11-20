{ config, lib, ... }:
let
  ports = lib.attrValues config.ports;
  noCollision = l: lib.length (lib.unique l) == lib.length l;
in
{
  options.ports = lib.mkOption {
    type = with lib.types; attrsOf port;
    default = { };
  };

  config = {
    assertions = [
      {
        assertion = noCollision ports;
        message = "ports collision";
      }
    ];

    ports = {
      headscale = 40010;
      headscale-metrics = 40011;

      xray-upstream = 40100;

      niks3 = 50000;

      sing-box-api = 50010;
      sing-box-clash-api = 50011;
    };
  };
}
