{
  systemd.network.networks."40-ens7" = {
    name = "ens7";
    address = [ "47.96.132.15/19" ];
  };

  profiles.sing-box.tailscale.advertiseRoutes = [
    "10.112.32.0/23"
  ];
}
