{ config, pkgs, ... }:
{
  sops.secrets."user-password/sun" = {
    neededForUsers = true;
  };

  users.users.sun = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      # "incus-admin"
      # "libvirtd"
    ];
    hashedPasswordFile = config.sops.secrets."user-password/sun".path;
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
  home-manager.users.sun = import ./_sunHome.nix;

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
