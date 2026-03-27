let
  routerId = "10.112.8.5";
in
{
  services.bird = {
    enable = true;
    config = ''
      log syslog all;
      router id ${routerId};

      protocol device {
      }

      protocol kernel {
        learn all;
        merge paths on;
        ipv4 {
          import all;
          export filter {
            if source != RTS_BGP then reject;
            accept;
          };
        };
      }

      protocol bgp svc {
        local as 64513;
        neighbor 10.112.8.1 internal;
        keepalive time 3;
        hold time 9;
        connect retry time 5;
        ipv4 {
          import all;
          export filter {
            if source != RTS_BGP then reject;
            accept;
          };
          next hop self;
          add paths rx;
          require add paths on;
        };
      }
    '';
  };

  networking.firewall.interfaces.svc.allowedTCPPorts = [ 179 ];

  boot.kernel.sysctl = {
    "net.ipv4.fib_multipath_hash_policy" = 1;
  };
}
