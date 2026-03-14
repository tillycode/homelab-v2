{
  systemd.network.links = {
    "40-k8s" = {
      matchConfig.Path = "pci-0000:02:00.0";
      linkConfig.Name = "k8s";
    };
    "40-eth0" = {
      matchConfig.Path = "pci-0000:03:00.0";
      linkConfig.Name = "eth0";
    };
  };

  systemd.network.networks."40-k8s" = {
    matchConfig.Name = "k8s";
    DHCP = "yes";
    # use eth0 gateway
    networkConfig = {
      IPv6PrivacyExtensions = "kernel";
      Domains = "~hasee.internal";
    };
    dhcpV4Config.UseGateway = false;
    routes = [
      {
        # Pod CIDR
        Gateway = "10.0.2.1";
        Destination = "10.112.0.0/21";
      }
      {
        # Service CIDR
        Gateway = "10.0.2.1";
        Destination = "10.112.9.0/24";
      }
    ];
  };
}
