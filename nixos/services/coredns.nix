{
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.coredns = {
    enable = true;
    config = ''
      (snip) {
        bind 169.254.23.1
        errors
        loadbalance
        cache
        log
      }
      k8s.szp.io {
        import snip
        forward . 10.112.10.10
      }
      szp15.com {
        import snip
        template ANY ANY invalid.szp15.com {
          rcode NXDOMAIN
        }
        rewrite cname exact ingress.szp15.com. invalid.szp15.com.
        forward . 10.112.10.10 {
          next NXDOMAIN
        }
        forward . /run/systemd/resolve/resolv.conf
      }
      szp.io {
        import snip
        forward . /run/systemd/resolve/resolv.conf
      }
    '';
  };

  systemd.network.netdevs."40-coredns" = {
    netdevConfig = {
      Name = "coredns";
      Kind = "dummy";
    };
  };

  systemd.network.networks."40-coredns" = {
    matchConfig.Name = "coredns";
    address = [ "169.254.23.1/32" ];
    networkConfig = {
      Domains = "~szp.io ~szp15.com";
      DNS = "169.254.23.1";
      LinkLocalAddressing = "no";
    };
  };
}
