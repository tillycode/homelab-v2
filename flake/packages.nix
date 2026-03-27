{ inputs, lib, ... }:
let
  getPackages = pkgs: (import ../pkgs { inherit pkgs; });
  filterPackage =
    system: package: !package.meta.broken or false && lib.meta.availableOn { inherit system; } package;
  flattenAndFilterPackages =
    system: packages:
    lib.pipe packages [
      (lib.mapAttrsToListRecursiveCond (p: v: !lib.isDerivation v) (
        p: v: lib.nameValuePair (lib.concatStringsSep "/" p) v
      ))
      (lib.filter (x: lib.isDerivation x.value && filterPackage system x.value))
      lib.listToAttrs
    ];
  inherit (inputs) nixpkgs-unstable;
in
{
  perSystem =
    { system, ... }:
    {
      # pkgs has already include the overlay, reimport it to avoid double overlay
      packages = flattenAndFilterPackages system (
        getPackages (
          import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.unstable ];
          }
        )
      );
    };

  flake.overlays.default = final: prev: getPackages prev;
  # inherit some unstable packages
  flake.overlays.unstable = final: prev: {
    # claude-code v2.1.51 supports remote control.
    claude-code = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/cl/claude-code/package.nix" { };
    openbao = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/op/openbao/package.nix" { };
    code-cursor = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/co/code-cursor/package.nix" {
      buildVscode =
        final.callPackage "${nixpkgs-unstable}/pkgs/applications/editors/vscode/generic.nix"
          { };
    };
  };
}
