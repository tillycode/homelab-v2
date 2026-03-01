{ lib, config, ... }:
let
  inherit (config.system) name;
  peers = {
    router = {
      PublicKey = "YBPLxVf9PwAytocbmtOaAjoWRX42evJUs8NSdHNL6SA=";
      PresharedKeyFile = config.sops.secrets."wireguard/presharedKey".path;
      AllowedIPs = [
        "10.112.34.1/32"
        "10.112.0.0/19"
      ];
    };
    hgh0 = {
      PublicKey = "dwSUwckjv4Vb+jCo6uZNWUIGXE5JZM8KqzUpZSlMbHg=";
      PresharedKeyFile = config.sops.secrets."wireguard/presharedKey".path;
      AllowedIPs = [
        "10.112.34.2/32"
        "10.112.32.0/23"
      ];
      PersistentKeepalive = 25;
      Endpoint = "hgh0.szp15.com:51820";
    };
  };
in
{
  systemd.network.netdevs."40-wg0" = {
    netdevConfig = {
      Kind = "wireguard";
      Name = "wg0";
    };
    wireguardConfig = {
      ListenPort = 51820;
      PrivateKeyFile = config.sops.secrets."wireguard/privateKeys/${name}".path;
      RouteTable = "main";
    };
    wireguardPeers = lib.attrValues (lib.filterAttrs (n: peer: n != name) peers);
  };

  systemd.network.networks."40-wg0" = {
    matchConfig.Name = "wg0";
    linkConfig.MTUBytes = 1412; # for PPPoE
    address = [
      (lib.head peers.${name}.AllowedIPs)
    ];
  };

  sops.secrets."wireguard/privateKeys/${name}" = {
    owner = "systemd-network";
  };
  sops.secrets."wireguard/presharedKey" = {
    owner = "systemd-network";
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];
}
