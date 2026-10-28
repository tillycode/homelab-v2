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
      crossRegionEndpoints.cn = [ "fdfe:3c59:ba97::8" ];
    };
    hkg0 = {
      id = 4;
      endpoint = [ "hkg0.eh578599.xyz" ];
      region = "global";
      crossRegionEndpoints.cn = [ "fdfe:3c59:ba97::9" ];
    };
    hkg1 = {
      id = 5;
      endpoint = [ "hkg1.eh578599.xyz" ];
      region = "global";
      crossRegionEndpoints.cn = [ "fdfe:3c59:ba97::a" ];
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
      local_port = 4500;
      remote_port = 4500;
      keyingtries = 0;
      dpd_delay = "30s";
      local_addrs = [ "%any" ];
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
      to.endpoint or null
    else
      to.crossRegionEndpoints.${from.region} or null;
  initiates = peer: endpoint self peer != null && (endpoint peer self == null || self.id < peer.id);
  peers = lib.filterAttrs (
    peerName: peer: peerName != selfName && (endpoint self peer != null || endpoint peer self != null)
  ) allNodes;
  proxyEndpoints = lib.concatMap (
    peer: lib.optionals (self.region != peer.region && endpoint self peer != null) (endpoint self peer)
  ) (lib.attrValues peers);
  nodeNames = [ selfName ] ++ lib.attrNames peers;
in
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

  # strongswan doesn't provide an option to set a per-connection IKE mark.
  # only ESP traffic is marked. Therefore, we need to mark IKE traffic manually.
  networking.nftables.tables.ipsec-ike = lib.mkIf (proxyEndpoints != [ ]) {
    family = "inet";
    content = ''
      chain output {
        type route hook output priority mangle; policy accept;
        ${lib.concatMapStringsSep "\n" (
          addr:
          let
            family = if lib.hasInfix ":" addr then "ip6" else "ip";
          in
          ''
            ${family} daddr ${addr} udp sport 4500 udp dport 4500 meta mark set 0x2023;
          ''
        ) proxyEndpoints}
      }
    '';
  };

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
