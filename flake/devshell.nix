{
  perSystem =
    { config, pkgs, ... }:
    {
      devshells.default = {
        devshell.startup.pre-commit-hook.text = config.pre-commit.installationScript;
        devshell.startup.files.text = config.files.shellHook;
        devshell.packages = with pkgs; [
          # for deployment
          nixos-anywhere
          deploy-rs
          sops
          ssh-to-age
          opentofu
          s5cmd

          # for IDEs and documentation
          (python3.withPackages (
            ps: with ps; [
              mkdocs
              mkdocs-material
              # for development
              devPackages.scripts.editable
            ]
          ))
        ];
        env = [
          {
            name = "S3_ENDPOINT_URL";
            value = "https://s3.szp15.com";
          }
        ];
      };
    };
}
