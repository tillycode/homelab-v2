{
  systemd.network.links = {
    "10-eth0" = {
      matchConfig.Path = "pci-0000:07:00.0";
      linkConfig.Name = "eno1";
    };
    "10-enp1s0" = {
      matchConfig.Path = "pci-0000:06:00.0";
      linkConfig.Name = "enp1s0";
    };
  };
  networking.vlans = {
    lan = {
      id = 3;
      interface = "eno1";
    };
    svc = {
      id = 4;
      interface = "eno1";
    };
  };
  systemd.network.networks."40-eno1" = {
    linkConfig.MTUBytes = 9000;
    networkConfig.IPv6AcceptRA = false;
  };
  systemd.network.networks."40-lan" = {
    matchConfig.Name = "lan";
    DHCP = "yes";
    dhcpV4Config.RoutesToDNS = false;
    linkConfig.MTUBytes = 9000;
  };
  systemd.network.networks."40-svc" = {
    matchConfig.Name = "svc";
    linkConfig.MTUBytes = 9000;
    address = [
      "10.112.8.5/24"
    ];
    dns = [
      "10.112.35.1"
      "10.112.35.2"
    ];
    networkConfig.IPv6AcceptRA = false;
  };
  systemd.network.networks."40-wlan0" = {
    matchConfig.Name = "wlan0";
    DHCP = "yes";
    dhcpV4Config = {
      RoutesToDNS = false;
      RouteMetric = 1025;
    };
    ipv6AcceptRAConfig.RouteMetric = 1025;
  };
}
