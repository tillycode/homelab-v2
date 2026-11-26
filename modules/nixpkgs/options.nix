# control the pkgs argument passed to the reset of the modules
{ lib, flake-parts-lib, ... }:
{
  options.nixpkgs = {
    overlays = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = "Overlays.";
    };
    allowUnfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Allow unfree packages.";
    };
  };

  options.perSystem = flake-parts-lib.mkPerSystemOption {
    options.nixpkgs = {
      additionalPackages = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        description = "Additional packages to be added to nixpkgs.";
      };
    };
  };
}
