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
      aws-lc = callPackage (unstable + "/pkgs/by-name/aw/aws-lc/package.nix") { };
      codex =
        assert lib.assertMsg (lib.versionOlder prev.codex.version "0.153.0")
          "codex is updated in the upstream";
        (callPackage (unstable + "/pkgs/by-name/co/codex/package.nix") { }).overrideAttrs (oldAttrs: {
          patches = oldAttrs.patches or [ ] ++ [
            ./codex-gstreamer-v1-26.patch
          ];
        });

      pnpm_10 =
        assert lib.assertMsg (lib.versionOlder prev.pnpm_10.version "10.34.7")
          "pnpm_10 is updated in the upstream";
        callPackage (unstable + "/pkgs/development/tools/pnpm/generic.nix") {
          version = "10.34.7";
          hash = "sha256-xyn2U44AXSNIiZEEZv0cTESv+wso6obZP8+IqhrvppQ=";
          nodejs = null;
        };
      openbao =
        assert lib.assertMsg (lib.versionOlder prev.openbao.version "2.7.0")
          "OpenBao is updated in the upstream";
        callPackage (unstable + "/pkgs/by-name/op/openbao/package.nix") { };
      openbaoPlugins =
        assert lib.assertMsg (!prev ? openbaoPlugins) "openbaoPlugins is added in the upstream";
        callPackage (unstable + "/pkgs/by-name/op/openbao/plugins.nix") { };

      # Use sing-box from nixpkgs-unstable. See NixOS/nixpkgs#558400
      sing-box =
        assert lib.assertMsg (lib.versionOlder prev.sing-box.version "1.14.0")
          "sing-box is updated in the upstream";
        callPackage (unstable + "/pkgs/by-name/si/sing-box/package.nix") { };
      sing-box-dashboard =
        assert lib.assertMsg (!prev ? sing-box-dashboard) "sing-box-dashboard is added in the upstream";
        callPackage (unstable + "/pkgs/by-name/si/sing-box-dashboard/package.nix") { };
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
    bird3 = prev.bird3.overrideAttrs (oldAttrs: {
      patches = oldAttrs.patches or [ ] ++ [
        # see https://trubka.network.cz/archives/list/bird-users@network.cz/thread/JDYJ2ZNHDJQY3HC7CPGYTT37L4SQ6IEM/
        (final.fetchpatch {
          url = "https://gitlab.nic.cz/labs/bird/-/commit/f6b9ad8be0b2f6eca29cf4b8967fb52dae55a69d.patch";
          hash = "sha256-B8c+nLdPSUoSpkJNmMELLiDG4CbYrFFvUW4G5AwlHSs=";
        })
        (final.fetchpatch {
          url = "https://gitlab.nic.cz/labs/bird/-/commit/082108137526e63bdbd447cddbf949b9ba7461d3.patch";
          decode = "sed 's/SKIP_BACK(const struct rt_pending_export/SKIP_BACK(struct rt_pending_export/'";
          hash = "sha256-tS/+UrYRAzxvZ2bq+odgNT3/eQ1hSzypnKP68rLOQ+M=";
        })
      ];
    });
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
}
