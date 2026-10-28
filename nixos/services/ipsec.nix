{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (config.system) name;
  nodes = {
    hgh0 = {
      id = 0;
      endpoint = [ "hgh0.szp15.com" ];
    };
    router = {
      id = 1;
    };
  };
  peers = lib.filterAttrs (peerName: peer: peerName != name) nodes;
  me = nodes.${name};
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
        encap = true;
        local_port = 4500;
        remote_port = 4500;
        keyingtries = 0;
        dpd_delay = "30s";
        local_addrs = [ "%any" ];
        remote_addrs = if initiates peer then peer.endpoint else [ "%any" ];
        local.host = {
          auth = "pubkey";
          pubkeys = [ config.sops.secrets."ipsec/publicKeys/${name}".path ];
        };
        remote.peer = {
          auth = "pubkey";
          pubkeys = [ config.sops.secrets."ipsec/publicKeys/${peerName}".path ];
        };
        children = {
          "${peerName}-net" = {
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
            close_action = if initiates peer then "trap" else "none";
            updown = "${lib.getExe pkgs.swan-updown} --prefix mesh-";
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
