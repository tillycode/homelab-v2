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
  networking.firewall.enable = false;
}
