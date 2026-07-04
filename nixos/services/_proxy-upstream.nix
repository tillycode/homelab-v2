{ config, lib, ... }:
{
  assertions = [
    {
      assertion = config.services.nginx.enable;
      message = "nginx is a required dependency for proxy server";
    }
  ];

  services.nginx.defaultListen = lib.mkDefault [
    {
      addr = "0.0.0.0";
      port = 80;
      ssl = false;
    }
    {
      addr = "[::0]";
      port = 80;
      ssl = false;
    }
    {
      addr = "[::1]";
      port = 40100;
      ssl = true;
    }
  ];

  services.nginx.virtualHosts."${config.system.name}.eh578599.xyz" = {
    enableACME = true;
    forceSSL = true;
    default = true;
    locations."/" = {
      root = "/var/www/proxy/non-existent";
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/www/proxy 0755 nginx nginx - -"
  ];
}
