{ lib, inputs, ... }:
{
  options = {
    zones = lib.mkOption {
      type = lib.types.attrsOf inputs.dns.lib.types.zone;
      default = { };
      description = "DNS zones";
    };
  };
}
