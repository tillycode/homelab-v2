{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    k9s
    kubectl
    kubernetes-helm
  ];

  systemd.user.tmpfiles.rules = [
    "L+ ${config.home.homeDirectory}/.kube - - - - ${config.xdg.configHome}/kube"
    "d ${config.xdg.configHome}/kube 0755 - - - -"
  ];
}
