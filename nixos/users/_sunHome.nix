{ pkgs, profiles, ... }:
{
  imports = with profiles; [
    programs.fcitx
    programs.desktop-apps
    programs.nix-dev
    programs.attic
    services.xdg-portal
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Ziping Sun";
      user.email = "me@szp.io";
      commit.gpgSign = true;
      init.defaultBranch = "master";
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      if [ $TERM = "xterm-kitty" ]
        alias ssh="kitty +kitten ssh"
      end
      starship init fish | source
    '';
    # plugins = with pkgs.fishPlugins; [
    #   {
    #     name = "tide";
    #     src = tide.src;
    #   }
    # ];
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$git_state$character";
      right_format = "$all";
      git_status = {
        stashed = "\\$$count";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇡$ahead_count⇣$behind_count";
        conflicted = "=$count";
        deleted = "✘$count";
        renamed = "»$count";
        modified = "!$count";
        staged = "+$count";
        untracked = "?$count";
      };
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

  programs.neovim.enable = true;
  programs.neovim.viAlias = true;

  programs.vscode.enable = true;
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
  };

  xdg = {
    enable = true;
    userDirs.enable = true;
  };

  home.sessionVariables = {
    KUBECONFIG = "$HOME/.kube/config";
  };

  home.packages = with pkgs; [
    k9s
    kubectl
    kubernetes-helm
    cilium-cli
    awscli2
    minio-client
    code-cursor
    # zed-editor
    nil
    netease-cloud-music-gtk
    minikube
  ];

  programs.mise.enable = true;
  programs.mise.enableFishIntegration = true;

  home.stateVersion = "23.11";
}
