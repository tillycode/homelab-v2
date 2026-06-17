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
      global
        log /dev/log local0 info
        expose-experimental-directives

      defaults
        log global
        timeout connect 5s
        timeout client 1m
        timeout server 1m

      frontend http
        mode http
        option httplog
        bind *:80,[::]:80
        redirect scheme https code 301 if !{ path_beg /.well-known/acme-challenge/ }
        acl http_hosts hdr(host) -i -f /etc/haproxy/http-hosts.txt
        use_backend lego_http if http_hosts
        default_backend nginx_http

      frontend tls
        mode tcp
        option tcplog
        bind *:443,[::]:443
        tcp-request inspect-delay 5s
        tcp-request content accept if { req.ssl_hello_type 1 }
        acl http_hosts req.ssl_sni -i -f /etc/haproxy/http-hosts.txt
        acl tls_hosts req.ssl_sni -i -f /etc/haproxy/tls-hosts.txt
        use_backend haproxy_tls if http_hosts
        use_backend k8s_tls if tls_hosts
        default_backend nginx_tls

      frontend https
        mode http
        option httplog
        bind [::1]:9443 accept-proxy ssl crt-list /etc/haproxy/certificates.txt
        http-request normalize-uri path-strip-dot
        http-request normalize-uri path-strip-dotdot full
        http-request normalize-uri path-merge-slashes
        http-request normalize-uri percent-decode-unreserved strict
        http-request normalize-uri percent-to-uppercase strict
        http-request deny deny_status 403 if { hdr(host) -i vault.szp15.com } !{ path_reg -f /etc/haproxy/vault.szp15.com/paths.txt }
        default_backend k8s_https

      backend lego_http
        mode http
        server default [::1]:1360

      backend nginx_http
        mode http
        server default [::1]:8080 check

      backend nginx_tls
        mode tcp
        server default [::1]:8443 send-proxy-v2

      backend k8s_tls
        mode tcp
        server default 10.112.10.100:442 check send-proxy-v2

      backend k8s_https
        mode http
        server default 10.112.10.100:442 ssl sni-auto ca-file /etc/ssl/certs/ca-certificates.crt send-proxy-v2

      backend haproxy_tls
        mode tcp
        server default [::1]:9443 send-proxy-v2
    '';
  };

  environment.etc."haproxy/http-hosts.txt".text = ''
    vault.szp15.com
  '';
  environment.etc."haproxy/tls-hosts.txt".text = ''
    whoami.szp15.com
  '';
  environment.etc."haproxy/certificates.txt".text = ''
    /var/lib/acme/vault.szp15.com/full.pem
  '';
  environment.etc."haproxy/vault.szp15.com/paths.txt".text = ''
    ^/v1/auth/github/login$
    ^/v1/identity/oidc/\.well-known(/.*)?$
    ^/v1/github/token/[\w-]+$
  '';

  systemd.services.haproxy.reloadTriggers = [
    config.environment.etc."haproxy/http-hosts.txt".source
    config.environment.etc."haproxy/tls-hosts.txt".source
    config.environment.etc."haproxy/certificates.txt".source
    config.environment.etc."haproxy/vault.szp15.com/paths.txt".source
  ];

  security.acme.certs."vault.szp15.com" = {
    group = "haproxy";
    listenHTTP = "[::1]:1360";
    webroot = null;
    reloadServices = [ "haproxy.service" ];
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
}
