{ inputs, lib, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          inputs.self.overlays.default
          inputs.self.overlays.unstable
        ];
        config.allowUnfreePredicate =
          pkg:
          lib.elem (lib.getName pkg) [
            "1password"
            "1password-cli"
            "claude-code"
            "cursor"
            "vscode"
            "wpsoffice"

            "corefonts"
            "vista-fonts"
            "vista-fonts-chs"
            "vista-fonts-cht"

            "pantum-driver"
            "nvidia-settings"
            "nvidia-x11"
          ];
      };
      legacyPackages = pkgs;
    };
}
