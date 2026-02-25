{
  systemd.network.links = {
    "40-eth0" = {
      matchConfig.Path = "pci-0000:03:00.0";
      linkConfig.Name = "eth0";
    };
    "40-wlan0" = {
      matchConfig.Path = "pci-0000:04:00.0";
      linkConfig.Name = "wlan0";
    };
    "40-svc" = {
      matchConfig.Path = "pci-0000:00:14.0-usb-0:*:1.0";
      linkConfig.Name = "svc";
    };
  };

  systemd.network.networks = {
    "40-eth0" = {
      matchConfig.Name = "eth0";
      DHCP = "ipv4";
      # avoid accidentally gain global IPv6 address
      networkConfig.IPv6AcceptRA = false;
    };
    "40-wlan0" = {
      matchConfig.Name = "wlan0";
      linkConfig.Unmanaged = true;
    };
    "40-svc" = {
      matchConfig.Name = "svc";
      linkConfig.MTUBytes = 9000;
      gateway = [ "10.112.8.1" ];
      dns = [
        "10.112.35.1"
        "10.112.35.2"
      ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
      };
    };
  };

  networking.firewall.enable = false;
}
