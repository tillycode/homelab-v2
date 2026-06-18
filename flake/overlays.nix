{ inputs, lib, ... }:
{
  flake.overlays.unstable = final: prev: {
    # Use latest headscale, since there exist breaking changes from the previous version.
    # And I don't want to migrate after the latest headscale gets into the upstream.
    headscale =
      (prev.headscale.overrideAttrs (oldAttrs: rec {
        version = "0.29.0";
        src =
          assert lib.assertMsg (lib.versionOlder oldAttrs.version "0.29.0")
            "headscale is updated in the upstream";
          final.fetchFromGitHub {
            owner = "juanfont";
            repo = "headscale";
            tag = "v${version}";
            hash = "sha256-gXL13uhpdjFvqm9DLexBTz3yu7/Q2f/otMsR/pSUBEA=";
          };
        vendorHash = "sha256-fzKyXNMw/2yAEhaTZu0n1NXatPO2IP0HFA2ey1vZIYM=";
      })).override
        {
          # headscale requires go 1.26.4
          buildGoModule = final.buildGoModule.override {
            go = final.go.overrideAttrs (oldAttrs: rec {
              version = "1.26.4";
              src =
                assert lib.assertMsg (lib.versionOlder oldAttrs.version "1.26.4") "go is updated in the upstream";
                final.fetchurl {
                  url = "https://go.dev/dl/go${version}.src.tar.gz";
                  hash = "sha256-T2aKMvv8ETLmqIH7lowvHa2mMUkqM5IRc1+7JVpCYC0=";
                };
            });
          };
        };
  };

  flake.overlays.fixups = final: prev: {
    nix-eval-jobs = prev.nix-eval-jobs.overrideAttrs (oldAttrs: {
      patches =
        assert lib.assertMsg (lib.versionOlder oldAttrs.version "2.34.2")
          "nix-eval-jobs is updated in the upstream";
        (oldAttrs.patches or [ ])
        ++ [
          # make sure cacheStatus is reported correctly, so that nix-fast-build can skip cached builds.
          # see https://github.com/NixOS/nix-eval-jobs/pull/414
          (final.fetchpatch {
            url = "https://github.com/NixOS/nix-eval-jobs/commit/bc08a27d9974aee4a617b1d9df68fd8055f13f07.patch";
            hash = "sha256-aJG+qW/4ggSLV93C/cvlq7liBhxIX38rw4QowQcszmw=";
          })
        ];
    });
  };

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
