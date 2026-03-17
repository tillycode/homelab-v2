{ inputs, lib, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          inputs.self.overlays.default
          inputs.self.overlays.unstable
        ];
        config.allowUnfreePredicate =
          pkg:
          lib.elem (lib.getName pkg) [
            "claude-code"
          ];
      };
      legacyPackages = pkgs;
    };
}
