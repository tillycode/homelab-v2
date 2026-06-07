{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    nixfmt
    nvd
    vulnix
    nix-tree
  ];
}
