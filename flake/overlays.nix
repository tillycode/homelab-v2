{ inputs, lib, ... }:
{
  flake.overlays.unstable =
    final: prev:
    let
      unstable = inputs.nixpkgs-unstable;
      inherit (final) callPackage;
    in
    {
      # For GPT-6 Astra. Copied from nixos-unstable.
      codex =
        assert lib.assertMsg (lib.versionOlder prev.codex.version "0.153.0")
          "codex is updated in the upstream";
        (callPackage (unstable + "/pkgs/by-name/co/codex/package.nix") { }).overrideAttrs (oldAttrs: {
          patches = oldAttrs.patches or [ ] ++ [
            ./codex-gstreamer-v1-26.patch
          ];
        });

      # Use sing-box from nixpkgs-unstable. See NixOS/nixpkgs#558400
      sing-box =
        assert lib.assertMsg (lib.versionOlder prev.sing-box.version "1.14.0")
          "sing-box is updated in the upstream";
        callPackage (unstable + "/pkgs/by-name/si/sing-box/package.nix") { };
      cronet-go = callPackage (unstable + "/pkgs/by-name/cr/cronet-go/package.nix") {
        gn = callPackage (unstable + "/pkgs/by-name/gn/gn/package.nix") { };
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
