{
  perSystem =
    { pkgs, lib, ... }:
    let
      package = pkgs.writeShellScript "flat-flake" ''
        set -e
        for file in "$@"; do
          ${lib.getExe pkgs.python3} ${./flat-flake.py} -f "$file"
        done
      '';
    in
    {
      pre-commit.settings.hooks.flat-flake = {
        name = "flat-flake";
        description = "Check flat flake dependencies";
        files = "flake\\.lock$";
        entry = "${package}";
      };
    };
}
