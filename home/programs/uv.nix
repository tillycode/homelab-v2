{ config, ... }:
{
  systemd.user.tmpfiles.rules = [
    # uv use hard link to link packages, so we need make its cache on the same filesystem with the projects.
    "L+ ${config.xdg.cacheHome}/uv - - - - ${config.home.homeDirectory}/Projects/.uv-cache"
    "d ${config.home.homeDirectory}/Projects/.uv-cache 0755 - - - -"
  ];
}
