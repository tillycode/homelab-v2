{
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
        redirect scheme https code 301

      frontend https
        bind *:443,:::443
        mode tcp
        tcp-request inspect-delay 5s
        tcp-request content accept if { req.ssl_hello_type 1 }
        use_backend whoami if { req.ssl_sni -i whoami.szp15.com }

      backend whoami
        mode tcp
        server whoami whoami.szp15.com:443 check
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
