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
    ];
    hashedPasswordFile = config.sops.secrets."user-password/sun".path;
    shell = pkgs.zsh;
  };
  users.groups.sun = {
    gid = 1000;
  };

  programs.zsh.enable = true;
  home-manager.users.sun = import ./_sunHome.nix;

  preservation.preserveAt.default.users.sun.files = [
    ".zsh_history"
  ];
  preservation.preserveAt.default.users.sun.directories = [
    ".aliyun"
    ".aws"
    ".cache"
    ".config"
    ".cursor"
    ".kube"
    ".local"
    ".npm"
    ".minikube"
    ".mc"
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
