{
  systemd.network.networks."10-eth0" = {
    name = "ens18";
    DHCP = "yes";
    address = [ "87.83.107.23/32" ];
    dns = [ "1.1.1.1" ];
    routes = [
      {
        Gateway = [ "100.100.0.0" ];
        GatewayOnLink = "yes";
      }
    ];
  };
}
