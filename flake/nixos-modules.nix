{ self, lib, ... }:
let
  modules = self.lib.listModules ../nixos-modules;
in
{
  flake.nixosModules = lib.pipe modules [
    (lib.mapAttrsToListRecursive (
      path: value: {
        name = lib.concatStringsSep "." path;
        value = import value;
      }
    ))
    lib.listToAttrs
  ];
}
