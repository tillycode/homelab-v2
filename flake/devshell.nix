{
  perSystem =
    { config, pkgs, ... }:
    {
      devshells.default = {
        devshell.startup.pre-commit-hook.text = config.pre-commit.installationScript;
        devshell.startup.files.text = config.files.shellHook;
        devshell.packages = with pkgs; [
          nixos-anywhere
          deploy-rs
          sops
          devPackages.pkgmgr

          # for IDEs
          python3
        ];
      };
    };
}
