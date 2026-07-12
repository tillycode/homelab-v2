{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;

    # default value changed to false in 26.05
    withRuby = false;
    withPython3 = false;

    plugins = with pkgs.vimPlugins; [
      mini-nvim
      nvim-spider
    ];
    initLua = builtins.readFile ./init.lua;
  };
}
