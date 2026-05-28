{ pkgs, ... }:
{
  imports = [
    ./_proxy-subscriptions.nix
  ];
  services.nginx.virtualHosts."szp15.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      root = "/var/www/blog";
      tryFiles = "$uri $uri/ =404";
    };
    locations."/subscription/" = {
      root = "/var/lib/proxy-subscriptions";
      tryFiles = "$uri $uri/ =404";
    };
    extraConfig = ''
      index index.html;
      error_page 404 /404.html;
    '';
  };

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
  users.users.nginx.extraGroups = [ "blog" ];
}
