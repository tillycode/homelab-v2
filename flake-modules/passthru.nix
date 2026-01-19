{ lib, ... }:
{
  options = {
    passthru = lib.mkOption {
      visible = false;
      type = lib.types.attrsOf lib.types.raw;
    };
  };
}
