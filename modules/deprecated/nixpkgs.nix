# We need to separate the config by aspects
{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.self.overlays.default
    inputs.self.overlays.unstable
    inputs.self.overlays.fixups
    inputs.self.overlays.hacks
  ];

  nixpkgs.allowUnfreePackages = [
    "1password"
    "1password-cli"
    "claude-code"
    "cursor"
    "steam"
    "steam-unwrapped"
    "vscode"
    "wpsoffice"
    "wechat"
    "feishu"

    "corefonts"
    "vista-fonts"
    "vista-fonts-chs"
    "vista-fonts-cht"

    "pantum-driver"
    "nvidia-settings"
    "nvidia-x11"
  ];
}
