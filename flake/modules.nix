{ self, ... }:
let
  nixosModules = self.lib.listModules ../nixos-modules;
  homeModules = self.lib.listModules ../home-modules;
in
{
  flake.nixosModules = self.lib.mkModules nixosModules;
  flake.homeModules = self.lib.mkModules homeModules;
}
