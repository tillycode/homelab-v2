{ lib, inputs, ... }:
let
  inherit (inputs) nixpkgs-unstable;
in
{
  flake.overlays.unstable = final: prev: {
    # claude-code v2.1.51 supports remote control.
    claude-code = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/cl/claude-code/package.nix" { };
    openbao = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/op/openbao/package.nix" { };
    code-cursor = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/co/code-cursor/package.nix" {
      buildVscode =
        final.callPackage "${nixpkgs-unstable}/pkgs/applications/editors/vscode/generic.nix"
          { };
    };
    opencode = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/op/opencode/package.nix" {
      # otherwise, got this error
      # > error: ModuleNotFound resolving "opencode-web-ui.gen.ts" (entry point)
      bun = final.callPackage "${nixpkgs-unstable}/pkgs/by-name/bu/bun/package.nix" { };
    };
    nix-fast-build = (
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
    # 1.5.0 has better support for github actions
    niks3 =
      (final.callPackage "${nixpkgs-unstable}/pkgs/by-name/ni/niks3/package.nix" { }).overrideAttrs
        (oldAttrs: rec {
          version = "1.6.0";
          src =
            assert lib.assertMsg (lib.versionOlder oldAttrs.version version) "niks3 is updated in the upstream";
            final.fetchFromGitHub {
              owner = "Mic92";
              repo = "niks3";
              tag = "v${version}";
              hash = "sha256-S2nSP6YWUz8I2uRZuAY93FoAAUa9TiZetLzjBv1n5vk=";
            };
          vendorHash = "sha256-KJM0m9QrtU6nJMmR+GBaJDNf5DUzmsVySroKIq0cMsE=";
        });
  };

  flake.overlays.fixups = final: prev: { };

  flake.overlays.hacks = final: prev: {
    # make deploy-rs has the same shape as the one from the upstream
    deploy-rs = prev.deploy-rs.overrideAttrs (oldAttrs: {
      passthru = oldAttrs.passthru or { } // {
        inherit (final) deploy-rs;
        inherit ((inputs.deploy-rs.overlays.default final prev).deploy-rs) lib;
      };
    });
  };
}
