{ pkgs, ... }:
let
  szp15Zone = pkgs.writeText "szp15.com.zone" ''
    $ORIGIN szp15.com.
    $TTL 3600

    @ IN SOA ns.szp15.com. me.szp.io. (
      12345      ; serial
      7200       ; refresh
      1800       ; retry
      86400      ; expire
      60         ; minimum
    )

    @     IN NS  ns.szp15.com.
    ns    IN A   10.112.8.1
  '';
  szpIoZone = pkgs.writeText "szp.io.zone" ''
    $ORIGIN szp.io.
    $TTL 3600

    @ IN SOA ns.szp.io. me.szp.io. (
      12345      ; serial
      7200       ; refresh
      1800       ; retry
      86400      ; expire
      60         ; minimum
    )

    @     IN NS  ns.szp.io.
    ns    IN A   10.112.8.1

    router.nodes   IN  A     10.112.8.1
    hasee01.nodes  IN  A     10.112.8.2
    hasee02.nodes  IN  A     10.112.8.3
    hasee03.nodes  IN  A     10.112.8.4
    desktop.nodes  IN  A     10.112.8.5
    hgh0.nodes     IN  CNAME hgh0.szp15.com.
    hkg0.nodes     IN  CNAME hkg0.eh578599.xyz.
    hkg1.nodes     IN  CNAME hkg1.eh578599.xyz.
    sjc0.nodes     IN  CNAME sjc0.eh578599.xyz.
  '';
in
{
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  # We use DNS hijacking to provide split-horizon DNS.
  # However, the authoritative section of the response may be composed by different upstream servers,
  # which results in inconsistency.
  #
  # Note that cert-manager use SOA record to check the propagation of the DNS records.
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
        rewrite continue {
          name suffix szp.io szp.io
          answer value internal-dns-k8s-gateway.internal-dns.szp.io. ns.szp.io.
        }
        forward . 10.112.10.10
      }
      szp15.com {
        import snip
        rewrite continue {
          name suffix szp15.com szp15.com
          answer value coen.ns.cloudflare.com. ns.szp15.com.
          answer value internal-dns-k8s-gateway.internal-dns.szp15.com. ns.szp15.com.
        }
        rewrite continue cname exact ingress.szp15.com. invalid.szp15.com.
        template IN ANY invalid.szp15.com {
          rcode NXDOMAIN
          authority "szp15.com. 60 IN SOA ns.szp15.com. me.szp.io. (12345 7200 1800 86400 60)"
        }
        file ${szp15Zone} {
          fallthrough
        }
        forward . 10.112.10.10 {
          next NXDOMAIN
        }
        forward . 223.5.5.5
      }
      szp.io {
        import snip
        file ${szpIoZone} {
          fallthrough
        }
        forward . 223.5.5.5
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
