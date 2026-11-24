{ config, ... }:
let
  cfg = config.services.caddy;
in
{
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
