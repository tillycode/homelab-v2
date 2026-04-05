{ config, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh.enable = true;
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
  };
  programs.zoxide.enable = true;
}
