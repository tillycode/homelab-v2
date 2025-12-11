{
  perSystem =
    { config, ... }:
    {
      devshells.default = {
        devshell.startup.pre-commit-hook.text = config.pre-commit.installationScript;
      };
    };
}
