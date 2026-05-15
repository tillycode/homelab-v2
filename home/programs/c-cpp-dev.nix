{ pkgs, ... }:
{
  home.packages = with pkgs; [
    clang-tools
    bear
  ];
}
