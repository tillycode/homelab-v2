{
  perSystem =
    { config, ... }:
    {
      # it add a check
      pre-commit.settings.hooks = {
        check-json.enable = true;
        check-added-large-files.enable = true;
        check-yaml.enable = true;
        # treefmt.enable = true;
      };
      devshells.default.devshell.startup.pre-commit-hook.text = config.pre-commit.installationScript;
    };
}
