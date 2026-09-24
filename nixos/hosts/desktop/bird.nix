{
  services.bird = {
    enable = true;
    config = ''
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
        metric 2048;
        merge paths on;
        ipv4 {
          import none;
          export all;
        };
      }

      protocol kernel kernel6 {
        metric 2048;
        merge paths on;
        ipv6 sadr {
          import none;
          export all;
        };
      }

      protocol babel {
        randomize router id;
        ipv4 {
          import all;
          export where source ~ [ RTS_BABEL, RTS_DEVICE ];
        };
        ipv6 sadr {
          import all;
          export where source ~ [ RTS_BABEL, RTS_DEVICE ];
        };
        interface "svc" {
          type wired;
          check link yes;
          extended next hop yes;
          next hop prefer ipv6;
        };
      }
    '';
  };

  networking.firewall.interfaces.svc.allowedTCPPorts = [ 179 ];
  networking.firewall.interfaces.svc.allowedUDPPorts = [ 6696 ];

  systemd.network.config.networkConfig.ManageForeignRoutes = false;

  boot.kernel.sysctl."net.ipv4.fib_multipath_hash_policy" = 1;
}
