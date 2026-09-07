{ inputs, lib, ... }:
{
  flake.overlays.unstable = final: prev: {
    # Use latest headscale, since there exist breaking changes from the previous version.
    # And I don't want to migrate after the latest headscale gets into the upstream.
    headscale = prev.headscale.overrideAttrs (oldAttrs: rec {
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
    });

    # For GPT-6 Astra. Copied from nixos-unstable.
    codex =
      let
        inherit (prev.callPackage (prev.path + "/pkgs/by-name/co/codex/fetchers.nix") { })
          fetchLibrustyV8
          ;
        fetchLibrustyV8SrcBinding =
          args:
          prev.fetchurl {
            name = "src_binding-${args.version}";
            url = "https://github.com/denoland/rusty_v8/releases/download/v${args.version}/src_binding_release_${prev.stdenv.hostPlatform.rust.rustcTarget}.rs";
            sha256 = args.shas.${prev.stdenv.hostPlatform.system};
            meta = {
              inherit (args) version;
              sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
            };
          };
        librusty_v8 = fetchLibrustyV8 {
          version = "150.4.0";
          shas = {
            x86_64-linux = "0v5hi3s56b6yk7nh5n0wygh7fn0j41yyjz5903r227qv0yvzssaq";
            aarch64-linux = "1lvx9xjzv7ibqvg5jnaxqaaim0lw4dwfgf6kw0pjfdrkmm97s5xp";
            riscv64-linux = "1lmx74mwavvx6rbwa7aq0pkjc58mxqy9hysbhpkhc3573360jdjh";
            aarch64-darwin = "043bgs3hcvrn1yzknrxchqnki8r9p7ggk9zbiaqwa8mqhlagin6c";
          };
        };
        librusty_v8_src_binding = fetchLibrustyV8SrcBinding {
          version = "150.4.0";
          shas = {
            x86_64-linux = "01l53l6nk4p5brpz2v3svqijx3hz5nqry8q7x12vdgbrwim849vp";
            aarch64-linux = "01l53l6nk4p5brpz2v3svqijx3hz5nqry8q7x12vdgbrwim849vp";
            riscv64-linux = "01l53l6nk4p5brpz2v3svqijx3hz5nqry8q7x12vdgbrwim849vp";
            aarch64-darwin = "0krrb2vh4skvfmzwpcqkl55bg2gyn943drqa8snp16lwz06dynna";
          };
        };
      in
      prev.codex.overrideAttrs (oldAttrs: rec {
        version = "0.153.4";
        src =
          assert lib.assertMsg (lib.versionOlder oldAttrs.version "0.153.4")
            "codex is updated in the upstream";
          final.fetchFromGitHub {
            owner = "openai";
            repo = "codex";
            tag = "rust-v${version}";
            hash = "sha256-lHiDj5SodaM3mh8goMm6esfejeAT+Y3JJWrRnyj6sJo=";
          };
        env = oldAttrs.env // {
          RUSTY_V8_ARCHIVE = librusty_v8;
          RUSTY_V8_SRC_BINDING_PATH = librusty_v8_src_binding;
        };
        cargoHash = "sha256-GG6kOXmCdq+bZLU2ul0DIVL8lDuweayvZvXn6+bcUZw=";
        cargoDeps = oldAttrs.cargoDeps.overrideAttrs (oldAttrs: {
          vendorStaging = oldAttrs.vendorStaging.overrideAttrs {
            outputHash = cargoHash;
          };
        });
      });
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
