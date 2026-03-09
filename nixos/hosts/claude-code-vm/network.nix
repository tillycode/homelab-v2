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
    networkConfig.IPv6PrivacyExtensions = "kernel";
    dhcpV4Config.UseGateway = false;
  };
}
