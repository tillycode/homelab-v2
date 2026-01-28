{
  services.bird = {
    enable = true;
    config = ''
      log stderr all;
      router id from "bond0";

      protocol device {
      }

      protocol kernel {
        learn all;
        merge paths on;
        ipv4 {
          import all;
          export filter {
            if source != RTS_BGP then reject;
            if bgp_path.last = 64512 then reject;
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

      protocol bgp cilium {
        local as 64513;
        neighbor 127.0.0.1 as 64512;
        passive on;
        # bypass localhost check
        multihop 2;
        hold time 9;
        keepalive time 3;
        ipv4 {
          import all;
          export none;
        };
      }
    '';
  };

  boot.kernel.sysctl = {
    "net.ipv4.fib_multipath_hash_policy" = 1;
  };
}
