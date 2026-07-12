{
  pkgs,
  profiles,
  config,
  ...
}:
{
  imports = with profiles; [
    programs.c-cpp-dev
    programs.fcitx
    programs.desktop-apps
    programs.go-dev
    programs.k8s-dev
    programs.neovim
    programs.nix-dev
    programs.niks3
    programs.podman
    programs.starship
    programs.uv
    programs.zsh
    services.xdg-portal
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Ziping Sun";
      user.email = "me@szp.io";
      commit.gpgSign = true;
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
    };
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.gpg.enable = true;
  # xfce4-session will launch gpg=agent by default.
  # See <https://docs.xfce.org/xfce/xfce4-session/advanced> for details.
  # Use the following commands to disable it.
  # ```shell
  # xfconf-query -c xfce4-session -p /startup/ssh-agent/enabled -n -t bool -s false
  # xfconf-query -c xfce4-session -p /startup/gpg-agent/enabled -n -t bool -s false
  # ```
  services.gpg-agent = {
    enable = true;
    # Yubikey supports multiple ways for ssh authentication and commit signing.
    # See <https://www.reddit.com/r/yubikey/comments/wzwilj/which_option_to_use_openpgp_piv_fido2sk_keys/>
    # for a comparison on theses ways.
    # Keys need to be listed in sshcontrol file, or have `Use-for-ssh: yes` attribute.
    # ```shell
    # gpg-connect-agent "KEYATTR 3770D6CF9F129A7A699AECA8248F3FE0BC366A21 Use-for-ssh: yes" /bye
    # ```
    # Use `ssh-add -l` to add host keys to sshcontrol file. In this way, when the
    # card is unplugged, the host key will come before the card key.
    enableSshSupport = true;
    enableExtraSocket = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  programs.vscode.enable = true;
  programs.ghostty.enable = true;

  xsession.enable = true;

  xdg = {
    enable = true;
    userDirs.enable = true;
    userDirs.setSessionVariables = false;
  };

  home.sessionVariables = {
    EDITOR = "vi";
    # oh-my-zsh set it defaults to "-R"
    LESS = "-FR";
    CLAUDE_CONFIG_DIR = "${config.xdg.configHome}/claude";
  };
  home.sessionPath = [
    "$HOME/.local/share/mise/shims"
  ];

  home.packages = with pkgs; [
    cilium-cli
    awscli2
    minio-client
    code-cursor
    netease-cloud-music-gtk
    minikube
  ];
  # for opencode
  home.file.".claude".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/claude";

  programs.mise.enable = true;
  programs.mise.enableZshIntegration = false;

  programs.opencode.enable = true;
  programs.claude-code.enable = true;

  home.stateVersion = "23.11";
}
