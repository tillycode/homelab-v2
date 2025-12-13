{
  perSystem =
    { config, pkgs, ... }:
    {
      devshells.default = {
        devshell.startup.pre-commit-hook.text = config.pre-commit.installationScript;
        devshell.packages = with pkgs; [
          deploy-rs
          sops
        ];
      };
    };
}
