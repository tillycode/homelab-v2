{
  systemd.network.links."10-eth0" = {
    matchConfig.PermanentMACAddress = "00:16:3c:0c:b6:a3";
    linkConfig.Name = "eth0";
  };

  systemd.network.networks."10-eth0" = {
    name = "eth0";
    address = [ "185.218.5.211/23" ];
    dns = [
      "8.8.8.8"
      "1.1.1.1"
    ];
    gateway = [ "185.218.4.1" ];
  };
}
