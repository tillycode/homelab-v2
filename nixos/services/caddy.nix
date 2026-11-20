{ config, ... }:
let
  cfg = config.services.caddy;
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "me@szp.io";
  };

  services.caddy = {
    enable = true;
    email = config.security.acme.defaults.email;
    acmeCA = config.security.acme.defaults.server;
  };

  preservation.preserveAt.default.directories = [
    {
      directory = cfg.dataDir;
      user = cfg.user;
      group = cfg.group;
    }
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    443
  ];
}
