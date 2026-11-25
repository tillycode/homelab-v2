{
  lib,
  config,
  pkgs,
  ...
}:
let
  allNodes = {
    router = {
      id = 0;
      endpoint = [ "router.nodes.szp.io" ];
      region = "cn";
    };
    hgh0 = {
      id = 1;
      endpoint = [ "hgh0.nodes.szp.io" ];
      region = "cn";
    };
    sjc1 = {
      id = 2;
      endpoint = [ "sjc1.nodes.szp.io" ];
      region = "global";
      ipv4Only = true;
    };
    lax0 = {
      id = 3;
      endpoint = [ "lax0.nodes.szp.io" ];
      region = "global";
      crossRegionVIP = "fd57:b9d9:4a63::1";
    };
    hkg0 = {
      id = 4;
      endpoint = [ "hkg0.nodes.szp.io" ];
      region = "global";
      # crossRegionVIP = "fd57:b9d9:4a63::2";
    };
    hkg1 = {
      id = 5;
      endpoint = [ "hkg1.nodes.szp.io" ];
      region = "global";
      crossRegionVIP = "fd57:b9d9:4a63::3";
    };
    laptop = {
      id = 6;
      region = "cn";
    };
  };

  mkPeerTunnels =
    peerName: peer:
    let
      crossRegion = self.region != peer.region;
      initiatesPeer = initiates peer;
      prefix = if crossRegion then "cross-" else "mesh-";
      mkTunnel =
        ver:
        let
          ifId = (if ver == "4" then 1000 else 2000) + peer.id;
        in
        {
          inherit ifId;
          interfaceName = "${prefix}${peerName}-v${ver}";
          connection = {
            version = 2;
            proposals = [ "aes128gcm16-prfsha256-curve25519" ];
            encap = true;
            mobike = false;
            local_port = 4500;
            remote_port = 4500;
            keyingtries = 0;
            dpd_delay = "30s";
            local_addrs =
              if crossRegion && initiatesPeer then [ config.networking.ipv6Address ] else [ "%any${ver}" ];
            remote_addrs = if initiatesPeer then endpoint self peer else [ "%any${ver}" ];
            local.host = {
              auth = "pubkey";
              id = "${selfName}.nodes.szp.io";
              pubkeys = [ config.sops.secrets."ipsec/publicKeys/${selfName}".path ];
            };
            remote.peer = {
              auth = "pubkey";
              id = "${peerName}.nodes.szp.io";
              pubkeys = [ config.sops.secrets."ipsec/publicKeys/${peerName}".path ];
            };
            children."${peerName}-v${ver}-net" = {
              esp_proposals = [ "aes128gcm16-curve25519" ];
              local_ts = [
                "0.0.0.0/0"
                "::/0"
              ];
              remote_ts = [
                "0.0.0.0/0"
                "::/0"
              ];
              if_id_in = toString ifId;
              if_id_out = toString ifId;
              start_action = if initiatesPeer then "trap|start" else "none";
              dpd_action = if initiatesPeer then "restart" else "clear";
              close_action = if initiatesPeer then "start" else "none";
              set_mark_in = "0/0xffffffff";
              set_mark_out = "0x2024";
            };
          };
        };
    in
    lib.optionalAttrs (crossRegion || !(peer.ipv4Only or false) && !(self.ipv4Only or false)) {
      "${peerName}-v6" = mkTunnel "6";
    }
    // lib.optionalAttrs (!crossRegion) {
      "${peerName}-v4" = mkTunnel "4";
    };

  selfName = config.system.name;
  self = allNodes.${selfName};
  endpoint =
    from: to:
    if from.region == to.region then
      to.endpoint or [ ]
    else
      lib.optional (to ? crossRegionVIP) to.crossRegionVIP;
  initiates = peer: endpoint self peer != [ ] && (endpoint peer self == [ ] || self.id < peer.id);
  peers = lib.filterAttrs (
    peerName: peer: peerName != selfName && (endpoint self peer != [ ] || endpoint peer self != [ ])
  ) allNodes;
  tunnels = lib.concatMapAttrs mkPeerTunnels peers;
  interfaces = lib.mapAttrs' (
    _: tunnel: lib.nameValuePair "40-${tunnel.interfaceName}" tunnel
  ) tunnels;
  nodeNames = [ selfName ] ++ lib.attrNames peers;
in
lib.mkMerge [
  {
    services.strongswan-swanctl = {
      enable = true;
      strongswan.extraConfig = ''
        charon {
          interfaces_ignore = sing0
          retry_initiate_interval = 30s
          install_routes = no
          routing_table = 0
          plugins {
            socket-default {
              fwmark = 0x2024
            }
          }
        }
      '';
      swanctl = {
        connections = lib.mapAttrs (_: tunnel: tunnel.connection) tunnels;
      };
    };

    systemd.network = {
      netdevs = lib.mapAttrs (_: tunnel: {
        netdevConfig = {
          Kind = "xfrm";
          Name = tunnel.interfaceName;
          MTUBytes = 1400;
        };
        xfrmConfig = {
          InterfaceId = tunnel.ifId;
          Independent = true;
        };
      }) interfaces;
      networks = lib.mapAttrs (_: tunnel: {
        name = tunnel.interfaceName;
        linkConfig = {
          Multicast = true;
          RequiredForOnline = false;
        };
        networkConfig = {
          LinkLocalAddressing = "ipv6";
          IPv6AcceptRA = false;
        };
      }) interfaces;
    };

    networking.firewall.allowedUDPPorts = [ 4500 ];

    sops.secrets = {
      "ipsec/privateKeys/${selfName}" = {
        path = "/run/secrets/ipsec/privateKeys/${selfName}.der";
      };
    }
    // lib.listToAttrs (
      lib.map (
        name:
        lib.nameValuePair "ipsec/publicKeys/${name}" {
          path = "/run/secrets/ipsec/publicKeys/${name}.der";
        }
      ) nodeNames
    );

    sops.genSecrets = lib.listToAttrs (
      lib.map (
        name:
        lib.nameValuePair "ipsec/publicKeys/${name}" {
          script = [
            "${lib.getExe pkgs.openssl}"
            "pkey"
            "-inform"
            "DER"
            "-pubout"
            "-outform"
            "DER"
          ];
          input = "ipsec/privateKeys/${name}";
        }
      ) nodeNames
    );

    systemd.tmpfiles.rules = [
      "L+ /etc/swanctl/private/node.der - - - - ${
        config.sops.secrets."ipsec/privateKeys/${selfName}".path
      }"
    ];
  }
  (lib.mkIf (self ? crossRegionVIP) {
    # install the cross region endpoint VIP without advertising it to the peers
    systemd.network.netdevs."40-ipsec-vip".netdevConfig = {
      Kind = "dummy";
      Name = "ipsec-vip";
    };
    systemd.network.networks."40-ipsec-vip" = {
      name = "ipsec-vip";
      address = [ "${self.crossRegionVIP}/128" ];
      networkConfig.LinkLocalAddressing = "no";
    };
  })
]
