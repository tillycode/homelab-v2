{
  self,
  lib,
  inputs,
  homeProfiles,
  ...
}:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.sharedModules = lib.attrValues self.homeModules;
  home-manager.extraSpecialArgs = {
    inherit inputs self;
    profiles = homeProfiles;
  };
}
