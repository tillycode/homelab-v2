{
  lib,
  inputs,
  config,
  withSystem,
  ...
}:
let
  flakeConfig = config;
in
{
  perSystem =
    {
      system,
      pkgs,
      config,
      ...
    }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays =
          flakeConfig.nixpkgs.overlays ++ lib.singleton (final: prev: config.nixpkgs.additionalPackages);
        config.allowUnfreePredicate =
          pkg: lib.elem (lib.getName pkg) flakeConfig.nixpkgs.allowUnfreePackages;
      };

      legacyPackages = pkgs;
    };

  flake.modules.nixos.base = { config, ... }: {
    nixpkgs.pkgs = withSystem config.nixpkgs.hostPlatform.system (x: x.pkgs);
  };
}
