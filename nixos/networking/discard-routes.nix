{ lib, ... }:
let
  privateNetworks = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "fc00::/7"
    "0.0.0.0/0"
    "::/0"
  ];
in
{
  systemd.network.networks."40-loopback" = {
    name = "lo";
    routes = lib.map (x: {
      Destination = x;
      Type = "unreachable";
      Metric = 4278198272;
    }) privateNetworks;
  };
}
