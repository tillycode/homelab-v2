{
  # see https://github.com/numtide/treefmt-nix?tab=readme-ov-file#configuration
  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        # should be covered by pre-commit
        flakeCheck = false;

        # see https://treefmt.com/latest/getting-started/configure/#global-options
        settings.on-unmatched = "fatal";
        settings.excludes = [
          "secrets/*"
          "*.terraform.lock.hcl"
        ];

        # json
        programs.prettier.enable = true;

        # python
        programs.ruff-format.enable = true;
        programs.ruff-check.enable = true;
        programs.ruff-check.extendSelect = [ "I" ];

        # nix
        programs.nixfmt.enable = true;

        # sh
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;
        settings.formatter.shfmt.includes = [ ".envrc" ];
        settings.formatter.shellcheck.includes = [ ".envrc" ];

        # toml
        programs.taplo.enable = true;

        # tf
        programs.terraform.enable = true;

        # zones
        settings.formatter.dnsfmt = {
          command = pkgs.writeShellApplication {
            name = "dnsfmt";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.diffutils
            ];
            text = ''
              temp=$(mktemp dnsfmt.XXXXXXXXXX)
              trap 'rm -f "$temp"' EXIT
              for file in "$@"; do
                ${pkgs.dnsfmt}/bin/dnsfmt -i=false "$file" > "$temp"
                if ! cmp -s "$file" "$temp"; then
                  mv "$temp" "$file"
                fi
              done
            '';
          };
          includes = [ "*.zone" ];
        };
      };
    };
}
