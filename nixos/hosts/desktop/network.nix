{
  profiles.bird = {
    wiredInterfaces = [ "svc" ];
    enableMesh = false;
  };

  systemd.network.links = {
    "10-eth0" = {
      matchConfig.Path = "pci-0000:07:00.0";
      linkConfig.Name = "svc";
    };
    "10-enp1s0" = {
      matchConfig.Path = "pci-0000:06:00.0";
      linkConfig.Name = "enp1s0";
    };
  };

  networking.hosts."10.112.8.1" = [
    "router.nodes.szp15.com"
    "router"
  ];
}
