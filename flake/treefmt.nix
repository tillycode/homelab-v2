{
  # see https://github.com/numtide/treefmt-nix?tab=readme-ov-file#configuration
  perSystem = {
    treefmt = {
      # should be covered by pre-commit
      flakeCheck = false;

      settings.on-unmatched = "warn";

      # nix
      programs.nixfmt.enable = true;

      # sh
      programs.shfmt.enable = true;
      programs.shellcheck.enable = true;
      settings.formatter.shfmt.includes = [ ".envrc" ];
      settings.formatter.shellcheck.includes = [ ".envrc" ];
    };
  };
}
