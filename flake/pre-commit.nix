{
  # see https://github.com/cachix/git-hooks.nix?tab=readme-ov-file#hooks
  perSystem =
    { pkgs, lib, ... }:
    let
      scripts = pkgs.devPackages.scripts.editable;
    in
    {
      pre-commit.check.enable = true;
      pre-commit.settings.hooks = {
        check-json.enable = true;
        check-added-large-files.enable = true;
        check-yaml.enable = true;
        check-yaml.args = [ "--unsafe" ]; # for !!python directives
        treefmt.enable = true;
        pre-commit-hook-ensure-sops.enable = true;

        # see https://pre-commit.com/#creating-new-hooks for custom hooks

        # ensure the flake doesn't have indirect dependencies
        flat-flake = {
          enable = true;
          description = "Check flat flake dependencies";
          files = "flake\\.lock$";
          entry = lib.getExe' scripts "flat-flake";
        };

        # ensure scripts are type-checked
        scripts-pyright = {
          enable = true;
          description = "Type-check scripts";
          files = "pkgs/dev-packages/.*\.py$";
          entry = "${pkgs.writeShellScript "pyright" ''
            cd pkgs/dev-packages
            exec ${lib.getExe pkgs.pyright} "$@"
          ''}";
          args = [
            "--warnings"
            "--pythonpath"
            (lib.getExe (pkgs.python3.withPackages (ps: [ scripts ])))
          ];
          pass_filenames = false;
        };
      };

      # HACK: we don't want to rebuild the pre-commit hook whenever we change the scripts.
      # Therefore, we use the editable version, which relies on PRJ_ROOT environment variable.
      # However, during `nix flake check`, PRJ_ROOT is not set.
      # And, there is no hook point for us to inject it, except for the package field.
      # See https://github.com/cachix/git-hooks.nix/blob/a1ef738813b15cf8ec759bdff5761b027e3e1d23/modules/pre-commit.nix#L86-L117
      pre-commit.settings.package = pkgs.writeShellScriptBin "pre-commit" ''
        export PRJ_ROOT=''${PRJ_ROOT:-"$PWD"}
        exec ${lib.getExe pkgs.pre-commit} "$@"
      '';
    };
}
