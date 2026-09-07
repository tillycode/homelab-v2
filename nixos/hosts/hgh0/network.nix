{
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv4.conf.default.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.default.forwarding" = 1;
  };

  systemd.network.networks."40-ens7" = {
    name = "ens7";
    address = [ "47.96.132.15/19" ];
  };
}
