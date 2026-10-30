{
  lib,
  config,
  pkgs,
  ...
}:
let
  allNodes = {
    hgh0 = {
      id = 0;
      endpoint = [ "hgh0.szp15.com" ];
      region = "cn";
    };
    router = {
      id = 1;
      region = "cn";
    };
    sjc1 = {
      id = 2;
      endpoint = [ "sjc1.eh578599.xyz" ];
      region = "global";
    };
    lax0 = {
      id = 3;
      endpoint = [ "lax0.eh578599.xyz" ];
      region = "global";
      crossRegionVIP = "fd57:b9d9:4a63::1";
    };
    hkg0 = {
      id = 4;
      endpoint = [ "hkg0.eh578599.xyz" ];
      region = "global";
      # crossRegionVIP = "fd57:b9d9:4a63::2";
    };
    hkg1 = {
      id = 5;
      endpoint = [ "hkg1.eh578599.xyz" ];
      region = "global";
      crossRegionVIP = "fd57:b9d9:4a63::3";
    };
  };

  mkConnection =
    peerName: peer:
    let
      crossRegion = self.region != peer.region;
      initiatesPeer = initiates peer;
    in
    {
      version = 2;
      proposals = [ "aes128gcm16-prfsha256-curve25519" ];
      encap = true;
      mobike = !crossRegion;
      local_port = 4500;
      remote_port = 4500;
      keyingtries = 0;
      dpd_delay = "30s";
      local_addrs =
        if crossRegion && initiatesPeer then
          map (x: lib.head (lib.splitString "/" x)) (
            lib.filter (lib.hasInfix ":") config.networking.loopback.address
          )
        else
          [ "%any" ];
      remote_addrs = if initiatesPeer then endpoint self peer else [ "%any" ];
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
      children = {
        "${peerName}-net" = {
          esp_proposals = [ "aes128gcm16-curve25519" ];
          local_ts = [
            "0.0.0.0/0"
            "::/0"
          ];
          remote_ts = [
            "0.0.0.0/0"
            "::/0"
          ];
          if_id_in = toString (1000 + peer.id);
          if_id_out = toString (1000 + peer.id);
          start_action = if initiatesPeer then "trap|start" else "none";
          dpd_action = if initiatesPeer then "restart" else "clear";
          close_action = if initiatesPeer then "start" else "none";
          updown = "${lib.getExe pkgs.swan-updown} --prefix ${
            lib.escapeShellArg (if crossRegion then "cross-" else "mesh-")
          } --mtu 1400";
          set_mark_out = if crossRegion then "0x2023" else "0x2024";
        };
      };
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
  nodeNames = [ selfName ] ++ lib.attrNames peers;
in
lib.mkMerge [
  {
    services.strongswan-swanctl = {
      enable = true;
      strongswan.extraConfig = ''
        charon {
          interfaces_ignore = sing0
        }
      '';
      swanctl = {
        connections = lib.mapAttrs mkConnection peers;
      };
    };

    networking.firewall.allowedUDPPorts = [ 4500 ];

    sops.secrets = {
      "ipsec/privateKeys/${selfName}" = {
        name = "ipsec/privateKeys/${selfName}.der";
      };
    }
    // lib.listToAttrs (
      lib.map (
        name:
        lib.nameValuePair "ipsec/publicKeys/${name}" {
          name = "ipsec/publicKeys/${name}.der";
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
