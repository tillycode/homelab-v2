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
    niks3 = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/ni/niks3/package.nix" { };
    opencode = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/op/opencode/package.nix" {
      # otherwise, got this error
      # > error: ModuleNotFound resolving "opencode-web-ui.gen.ts" (entry point)
      bun = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/bu/bun/package.nix" { };
    };
    nix-fast-build =
      # wait for the PR https://nixpk.gs/pr-tracker.html?pr=501027 to be merged
      (
        prev.nix-fast-build.overrideAttrs (oldAttrs: rec {
          version = "1.4.0";
          src =
            assert lib.assertMsg (lib.versionOlder oldAttrs.version version)
              "nix-fast-build is updated in the upstream";
            final.fetchFromGitHub {
              owner = "Mic92";
              repo = "nix-fast-build";
              tag = version;
              hash = "sha256-sH/KWX8NO8iurnnkI7w8eWMkbnRBbvEIK9IW4LnR0qQ=";
            };
        })
      );
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
