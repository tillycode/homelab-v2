{ inputs, lib, ... }:
{
  flake.overlays.unstable = final: prev: { };

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
