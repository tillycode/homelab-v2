{
  # see https://gist.github.com/nat-418/1101881371c9a7b419ba5f944a7118b0
  # xfconf-query -c xfce4-session -p /startup/ssh-agent/enabled -n -t bool -s false
  # xfconf-query -c xfce4-session -p /startup/gpg-agent/enabled -n -t bool -s false
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    # See microsoft/vscode#23991 to make VS Code follow the keyboard mappings.
    xkb.options = "caps:escape";
  };
}
