{ config, pkgs, ... }:
{
  imports = [
    ./_proxy-subscriptions.nix
  ];

  services.caddy.virtualHosts."szp15.com".extraConfig = ''
    root /var/www/blog
    encode zstd gzip

    file_server /subscription/* {
      root /var/lib/proxy-subscriptions
    }
    file_server

    handle_errors 404 {
      rewrite /404.html
      file_server
    }
  '';

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/www/blog";
      user = "blog";
      group = "blog";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/blog 0755 blog blog"
  ];

  users.users.blog = {
    isSystemUser = true;
    group = "blog";
    home = "/var/lib/blog";
    shell = pkgs.bash;
  };
  users.groups.blog = { };
  users.users.${config.services.caddy.user}.extraGroups = [ "blog" ];
}
