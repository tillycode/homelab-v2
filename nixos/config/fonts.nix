{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    source-serif
    source-sans
    source-han-serif
    source-han-sans

    maple-mono.NF-CN
    maple-mono.NL-NF-CN

    wqy_zenhei
    wqy_microhei

    corefonts
    vista-fonts
    vista-fonts-chs
    vista-fonts-cht

    noto-fonts-color-emoji
  ];

  fonts.fontconfig.defaultFonts = {
    serif = [
      "Source Serif 4"
      "Source Han Serif SC"
    ];
    sansSerif = [
      "Source Sans 3"
      "Source Han Sans SC"
    ];
    monospace = [ "Maple Mono NF CN" ];
    emoji = [ "Noto Color Emoji" ];
  };
  fonts.fontDir.enable = true;
}
