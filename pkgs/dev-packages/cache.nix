{
  lib,
  writeClosure,
  inputs,
  pkgs,
}:
let
  inherit (pkgs.extend inputs.self.overlays.fixups) nix-fast-build;
in
writeClosure (
  lib.attrValues (lib.removeAttrs inputs [ "self" ])
  ++ [
    nix-fast-build
  ]
)
