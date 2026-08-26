{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # internet
    firefox
    chromium
    telegram-desktop
    remmina
    qbittorrent
    wechat

    # games
    prismlauncher

    # music & video
    obs-studio
    vlc

    # office
    evince
    wpsoffice
    drawio
    freecad
    gimp

    # utilities
    blueman
    pavucontrol
    qalculate-gtk
    font-manager
    file-roller
    gnome-disk-utility
    wireshark
    xcolor
    xkill
    xfce4-appfinder
    seahorse
    d-spy
    bustle
    iwgtk

    # xfce plugins
    xfce4-pulseaudio-plugin
    xfce4-systemload-plugin
    xfce4-weather-plugin
    xfce4-whiskermenu-plugin

    # cli tools
    libqalculate
    ffmpeg
    man-pages
    man-pages-posix
    xclip
    bruno
  ];
}
