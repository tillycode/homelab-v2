{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (config.system) name;
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
    };
    hkg0 = {
      id = 4;
      endpoint = [ "hkg0.eh578599.xyz" ];
      region = "global";
    };
    hkg1 = {
      id = 5;
      endpoint = [ "hkg1.eh578599.xyz" ];
      region = "global";
    };
  };
  me = allNodes.${name};
  nodes = lib.filterAttrs (peerName: peer: peer.region == me.region) allNodes;
  peers = lib.filterAttrs (peerName: peer: peerName != name) nodes;
  initiates = peer: peer.endpoint or null != null && (me.endpoint or null == null || me.id < peer.id);
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
      connections = lib.mapAttrs (peerName: peer: {
        version = 2;
        proposals = [ "aes128gcm16-prfsha256-curve25519" ];
        encap = true;
        local_port = 4500;
        remote_port = 4500;
        keyingtries = 0;
        dpd_delay = "30s";
        local_addrs = [ "%any" ];
        remote_addrs = if initiates peer then peer.endpoint else [ "%any" ];
        local.host = {
          auth = "pubkey";
          id = "${name}.nodes.szp.io";
          pubkeys = [ config.sops.secrets."ipsec/publicKeys/${name}".path ];
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
            start_action = if initiates peer then "trap|start" else "none";
            dpd_action = if initiates peer then "restart" else "clear";
            close_action = if initiates peer then "start" else "none";
            updown = "${lib.getExe pkgs.swan-updown} --prefix mesh- --mtu 1400";
            set_mark_out = "0x2024";
          };
        };
      }) peers;
    };
  };

  networking.firewall.allowedUDPPorts = [ 4500 ];

  sops.secrets = {
    "ipsec/privateKeys/${name}" = {
      name = "ipsec/privateKeys/${name}.der";
    };
  }
  // lib.mapAttrs' (
    name: _:
    lib.nameValuePair "ipsec/publicKeys/${name}" {
      name = "ipsec/publicKeys/${name}.der";
    }
  ) nodes;

  sops.genSecrets = lib.mapAttrs' (
    name: _:
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
  ) nodes;

  systemd.tmpfiles.rules = [
    "L+ /etc/swanctl/private/node.der - - - - ${config.sops.secrets."ipsec/privateKeys/${name}".path}"
  ];
}
