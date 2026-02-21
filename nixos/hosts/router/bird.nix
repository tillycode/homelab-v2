{
  services.bird.enable = true;
  services.bird.config = ''
    log syslog all;
    router id 10.112.8.1;

    protocol device {
    }

    filter rts_bgp {
      if source != RTS_BGP then reject;
      accept;
    };

    protocol kernel {
      learn all;
      merge paths on;
      ipv4 {
        import all;
        export filter rts_bgp;
      };
    }

    protocol bgp svc {
      local as 64513;
      neighbor range 10.112.8.0/24 internal;
      rr client;
      dynamic name "svc";
      keepalive time 3;
      hold time 9;
      ipv4 {
        import all;
        export filter rts_bgp;
        add paths tx;
        require add paths on;
      };
    }
  '';

  networking.firewall.interfaces.svc.allowedTCPPorts = [ 179 ];

  boot.kernel.sysctl = {
    "net.ipv4.fib_multipath_hash_policy" = 1;
  };
}
