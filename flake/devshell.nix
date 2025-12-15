{
  perSystem =
    { config, pkgs, ... }:
    {
      devshells.default = {
        devshell.startup.pre-commit-hook.text = config.pre-commit.installationScript;
        devshell.startup.files.text = config.files.shellHook;
        devshell.packages = with pkgs; [
          deploy-rs
          sops
        ];
      };
    };
}
