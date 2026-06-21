{ pkgs, ... }:
let
  domain = "tailnet.szp15.com";
  port = 40010;
  metricsPort = 40011;
  jsonFormat = pkgs.formats.json { };
in
{
  # To setup headscale, run the following commands:
  #
  #     headscale users create ziping-sun --email ziping-sun@szp.io --display-name "Ziping Sun"
  #
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://${domain}";
      listen_addr = "[::1]:${toString port}";
      metrics_listen_addr = "[::1]:${toString metricsPort}";
      trusted_proxies = [ "::1/128" ];
      prefixes = {
        v4 = "100.112.36.0/24";
        v6 = "fd7a:115c:a1e0:7024::/64";
      };

      # DERP
      derp.server = {
        enabled = true;
        stun_listen_addr = "0.0.0.0:3478";
      };

      disable_check_updates = true;

      # POLICY
      # https://github.com/juanfont/headscale/blob/v0.25.1/hscontrol/policy/acls_types.go
      policy = {
        mode = "file";
        path = jsonFormat.generate "policy.json" {
        };
      };

      # DNS
      dns = {
        magic_dns = false;
        override_local_dns = false;
        nameservers.split = {
          "szp.io" = [ "10.112.35.1" ];
          "szp15.com" = [ "10.112.35.1" ];
        };
      };
      taildrop.enabled = false;
    };
  };

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/headscale";
      mode = "0700";
      user = "headscale";
      group = "headscale";
    }
  ];

  services.nginx.virtualHosts."${domain}" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://[::1]:${toString port}";
      proxyWebsockets = true;
    };
  };
}
