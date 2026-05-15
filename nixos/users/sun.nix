{ config, pkgs, ... }:
{
  sops.secrets."user-password/sun" = {
    neededForUsers = true;
  };

  users.users.sun = {
    isNormalUser = true;
    uid = 1000;
    group = "sun";
    extraGroups = [
      "wheel"
      "incus-admin"
    ];
    hashedPasswordFile = config.sops.secrets."user-password/sun".path;
    shell = pkgs.zsh;
  };
  users.groups.sun = {
    gid = 1000;
  };

  programs.zsh.enable = true;
  home-manager.users.sun = import ./_sunHome.nix;

  preservation.preserveAt.default.users.sun.directories = [
    ".cache"
    ".config"
    ".cursor"
    ".local"
    ".vscode-server"
    ".vscode"
    ".factorio"
    "Documents"
    "Downloads"
    "Projects"
    {
      directory = ".ssh";
      mode = "0700";
    }
    {
      directory = ".gnupg";
      mode = "0700";
    }
  ];
}
