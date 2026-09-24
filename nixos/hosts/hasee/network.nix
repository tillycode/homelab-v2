{ lib, ... }:
lib.mkMerge [
  {
    systemd.network.links = {
      "40-eth0" = {
        matchConfig.Path = "pci-0000:03:00.0";
        linkConfig.Name = "eth0";
      };
      "40-svc" = {
        matchConfig.Path = "pci-0000:04:00.0";
        linkConfig.Name = "svc";
      };
    };

    networking.useDHCP = false;
    systemd.network.networks."40-svc" = {
      name = "svc";
      linkConfig.MTUBytes = 9000;
      networkConfig = {
        IPv6AcceptRA = false;
        LinkLocalAddressing = "ipv6";
      };
    };

    networking.firewall.enable = false;

    networking.nameservers = [
      "10.112.35.1"
      "10.112.35.2"
    ];
  }
  {
    # trick systemd to think DNS is ready
    # see https://github.com/systemd/systemd/blob/v260.2/src/resolve/resolved-link.c#L695-L734.
    systemd.network.networks."40-svc".networkConfig = {
      DNS = "fe80::1";
      DNSDefaultRoute = false;
    };
  }
]
