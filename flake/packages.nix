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
  flake.overlays.fixups = final: prev: {
    # Downgrade bird to 3.1.5, because we're hitting this issue:
    # https://bird.network.cz/pipermail/bird-users/2026-January/018552.html
    bird3 = prev.bird3.overrideAttrs (oldAttrs: rec {
      version = "3.1.5";
      src = prev.fetchFromGitLab {
        domain = "gitlab.nic.cz";
        owner = "labs";
        repo = "bird";
        rev = "v${version}";
        hash = "sha256-UxaZhieUpHmPJwgLw+i6vbFsweOCQIZv2BEQfYtlPQQ=";
      };
    });
  };
}
