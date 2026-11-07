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
      ppp_2_5_5 =
        assert lib.assertMsg (lib.versionOlder prev.ppp.version "2.5.5") "ppp is updated in the upstream";
        prev.ppp.overrideAttrs (oldAttrs: rec {
          patches =
            # gcc15 build patch, merged sinced 2.5.3
            assert lib.assertMsg (
              lib.length oldAttrs.patches == 1
              &&
                (lib.head oldAttrs.patches).url
                == "https://github.com/ppp-project/ppp/commit/05361692ee7d6260ce5c04c9fa0e5a1aa7565323.patch"
            ) "ppp has an unexpected patch";
            [ ];
          version = "2.5.5";
          src = final.fetchFromGitHub {
            owner = "ppp-project";
            repo = "ppp";
            tag = "v${version}";
            hash = "sha256-Ny1To4tzfqUT13jMVgKuW36tjMB07bKDFUV+sLdOobM=";
          };
        });
      bird3 =
        assert lib.assertMsg (lib.versionOlder prev.bird3.version "3.4.0")
          "bird is updated in the upstream";
        callPackage (unstable + "/pkgs/by-name/bi/bird3/package.nix") { };

      # current stable nixpkgs buildVscode contains a bug due to ripgrep path being update
      # let's check if this is fixed in the future.
      buildVscode = callPackage (unstable + "/pkgs/applications/editors/vscode/generic.nix") { };
    };

  flake.overlays.fixups = final: prev: {
    frr = prev.frr.overrideAttrs (oldAttrs: {
      patches = oldAttrs.patches or [ ] ++ [
        # fix systemd compatibility issue
        (final.fetchpatch {
          url = "https://github.com/FRRouting/frr/commit/152fa011e439fdbc636753e265b7b3d1a08cd06f.patch";
          hash = "sha256-nFtGupvYOATLmtbKZ1TKlrTxJt4u3KJCtWuShJ/7xK4=";
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
