{
  # see https://github.com/cachix/git-hooks.nix?tab=readme-ov-file#hooks
  perSystem = {
    pre-commit.settings.hooks = {
      check-json.enable = true;
      check-added-large-files.enable = true;
      check-yaml.enable = true;
      treefmt.enable = true;
    };
  };
}
