{ pkgs, ... }:
{
  systemd.network.networks."40-ens7" = {
    name = "ens7";
    linkConfig.Unmanaged = true;
  };
  systemd.services."netns-ens7" = {
    path = with pkgs; [
      iproute2
    ];
    script = ''
      ip netns add ens7
      ip link set ens7 netns ens7
      ip netns exec ens7 ip addr add 47.96.132.15/19 dev ens7
      ip netns exec ens7 ip link set lo up
      ip netns exec ens7 ip link set ens7 up
      ip netns exec ens7 ip route add default via 47.96.159.253 dev ens7
    '';
    postStop = ''
      ip netns delete ens7 || true
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    after = [ "network.target" ];
    before = [ "haproxy.service" ];
    wantedBy = [ "haproxy.service" ];
  };
  profiles.haproxy.netns = "ens7";

  services.nginx.defaultListenAddresses = [
    "10.112.33.1"
    "[2408:4005:3c4:a40:d5b6:55ed:95b4:4eed]"
  ];

  profiles.sing-box.tailscale.advertiseRoutes = [
    "10.112.32.0/23"
  ];
}
