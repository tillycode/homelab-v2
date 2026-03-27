{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    nixfmt-rfc-style
    nvd
    vulnix
    nix-tree
  ];
}
