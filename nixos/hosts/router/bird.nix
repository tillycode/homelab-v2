{
  services.bird.enable = true;
  services.bird.config = ''
    log syslog all;
    ipv6 sadr table sadr6;

    protocol device {
      scan time 10;
    }

    protocol direct {
      ipv4;
      ipv6 sadr;
      interface "lo";
    }

    protocol kernel kernel4 {
      learn;
      metric 2048;
      merge paths on;
      ipv4 {
        import where net = 0.0.0.0/0;
        export all;
      };
    }

    protocol kernel kernel6 {
      learn;
      metric 2048;
      merge paths on;
      ipv6 sadr {
        import where net.dst = ::/0 && net.src = ::/0;
        export all;
      };
    }

    protocol babel {
      randomize router id;
      ipv4 {
        import all;
        export where source ~ [ RTS_BABEL, RTS_DEVICE, RTS_INHERIT ];
      };
      ipv6 sadr {
        import all;
        export where source ~ [ RTS_BABEL, RTS_DEVICE, RTS_INHERIT ];
      };
      interface "svc" {
        type wired;
        check link yes;
        extended next hop yes;
        next hop prefer ipv6;
      };
    }
  '';

  networking.firewall.interfaces.svc.allowedTCPPorts = [ 179 ];
  networking.firewall.interfaces.svc.allowedUDPPorts = [ 6696 ];

  boot.kernel.sysctl = {
    "net.ipv4.fib_multipath_hash_policy" = 1;
  };
}
