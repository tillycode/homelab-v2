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
        interface "lo", "vip";
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
        interface "mesh-*" {
          type tunnel;
          hello interval 20 s;
          extended next hop yes;
          next hop prefer ipv6;
          rtt cost 256;
          rtt max 270 ms;
        };
        interface "cross-*" {
          type tunnel;
          rxcost 512;
          hello interval 20 s;
          extended next hop yes;
          next hop prefer ipv6;
          rtt cost 256;
          rtt max 270 ms;
        };
      }
    '';
  };

  networking.firewall.allowedUDPPorts = [ 6696 ];

  systemd.network.config.networkConfig.ManageForeignRoutes = false;
}
