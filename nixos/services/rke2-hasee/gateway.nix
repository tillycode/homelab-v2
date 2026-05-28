{ config, ... }:
{
  assertions = [
    {
      assertion = config.services.nginx.enable;
      message = "nginx is a required dependency for gateway";
    }
  ];

  # haproxy resolves the DNS during startup. So it should be started after coredns.
  services.haproxy = {
    enable = true;
    config = ''
      defaults
        timeout connect 5s
        timeout client 1m
        timeout server 1m

      frontend http
        bind *:80,:::80
        mode http
        acl acme_path path_beg /.well-known/acme-challenge/
        redirect scheme https code 301 if !acme_path
        use_backend nginx_http

      frontend https
        bind *:443,:::443
        mode tcp
        tcp-request inspect-delay 5s
        tcp-request content accept if { req.ssl_hello_type 1 }
        use_backend k8s_ingress if { req.ssl_sni -i whoami.szp15.com }
        use_backend nginx_https

      backend k8s_ingress
        mode tcp
        server k8s_ingress 10.112.10.100:442 check send-proxy-v2

      backend nginx_http
        mode http
        server nginx_http [::1]:8080

      backend nginx_https
        mode tcp
        server nginx_https [::1]:8443 send-proxy-v2
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx.defaultListen = [
    {
      addr = "[::1]";
      port = 8080;
      ssl = false;
    }
    {
      addr = "[::1]";
      port = 8443;
      ssl = true;
      proxyProtocol = true;
    }
  ];

  services.nginx.virtualHosts."vault.szp15.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      return = "403";
    };
    locations."~ ^/v1/identity/oidc/.well-known/(openid-configuration|keys)$" = {
      proxyPass = "https://10.112.10.100:443";
      extraConfig = ''
        set_real_ip_from ::1;
        real_ip_header proxy_protocol;
        proxy_ssl_server_name on;
        proxy_ssl_name vault.szp15.com;
      '';
    };
  };
}
