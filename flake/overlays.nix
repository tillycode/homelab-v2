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
