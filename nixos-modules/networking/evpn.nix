{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.networking.evpn;
  vlanOption = { name, config, ... }: {
    options = {
      vid = mkOption {
        type = types.int;
        description = "VLAN ID";
      };
      vni = mkOption {
        type = types.int;
        description = "VNI for the VXLAN";
      };

      enableVRF = mkEnableOption "Enable VRF for this VLAN";
      vrfTable = mkOption {
        type = types.int;
        description = "VRF table ID for the EVPN";
      };
      vrfName = mkOption {
        type = types.str;
        default = name;
        description = "VRF interface name for the EVPN";
      };
      bridgeName = mkOption {
        type = types.str;
        default = "${config.vrfName}br";
        description = "VLAN interface name for the EVPN";
      };
    };
  };
in
{
  options.networking.evpn = {
    enable = mkEnableOption "EVPN";
    mtu = mkOption {
      type = types.int;
      default = 1350;
      description = "MTU for the EVPN interfaces";
    };
    vxlanLocal = mkOption {
      type = types.str;
      description = "Local IP address for the EVPN VXLAN interface";
    };
    macAddress = mkOption {
      type = types.str;
      description = "MAC address for the EVPN";
    };

    bridgeName = mkOption {
      type = types.str;
      default = "evpnbr";
      description = "Bridge name for the EVPN";
    };
    vxlanName = mkOption {
      type = types.str;
      default = "evpnvxlan";
      description = "VXLAN interface name for the EVPN";
    };
    vxlanPort = mkOption {
      type = types.int;
      default = 4789;
      description = "VXLAN port for the EVPN";
    };

    vlan = mkOption {
      type = types.attrsOf (types.submodule vlanOption);
      description = "VLAN configuration for the EVPN";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (x: x.vid >= 1 && x.vid <= 4094) (lib.attrValues cfg.vlan);
        message = "VLAN ID must be between 1 and 4094";
      }
      {
        assertion = lib.all (x: x.vni >= 1 && x.vni <= 16777215) (lib.attrValues cfg.vlan);
        message = "VNI must be between 1 and 16777215";
      }
      {
        assertion = lib.allUnique (lib.mapAttrsToList (_: x: x.vid) cfg.vlan);
        message = "VLAN IDs must be unique";
      }
      {
        assertion = lib.allUnique (lib.mapAttrsToList (_: x: x.vni) cfg.vlan);
        message = "VNIs must be unique";
      }
    ];

    systemd.network.netdevs = {
      "40-${cfg.bridgeName}" = {
        netdevConfig = {
          Kind = "bridge";
          Name = cfg.bridgeName;
          MTUBytes = cfg.mtu;
          MACAddress = cfg.macAddress;
        };
        bridgeConfig = {
          VLANFiltering = true;
          DefaultPVID = "none";
        };
      };
      "40-${cfg.vxlanName}" = {
        netdevConfig = {
          Kind = "vxlan";
          Name = cfg.vxlanName;
          MTUBytes = cfg.mtu;
          MACAddress = cfg.macAddress;
        };
        vxlanConfig = {
          MacLearning = false;
          DestinationPort = cfg.vxlanPort;
          External = true;
          VNIFilter = true;
          Independent = true;
          Local = cfg.vxlanLocal;
        };
      };
    }
    // lib.concatMapAttrs (
      _: x:
      lib.optionalAttrs x.enableVRF {
        "40-${x.bridgeName}" = {
          netdevConfig = {
            Kind = "vlan";
            Name = x.bridgeName;
            MTUBytes = cfg.mtu;
            MACAddress = cfg.macAddress;
          };
          vlanConfig = {
            Id = x.vid;
          };
        };
        "40-${x.vrfName}" = {
          netdevConfig = {
            Kind = "vrf";
            Name = x.vrfName;
          };
          vrfConfig = {
            Table = x.vrfTable;
          };
        };
      }
    ) cfg.vlan;

    systemd.network.networks = {
      "40-${cfg.bridgeName}" = {
        name = cfg.bridgeName;
        networkConfig = {
          LinkLocalAddressing = "no";
          VLAN = lib.concatMap (x: lib.optional x.enableVRF x.bridgeName) (lib.attrValues cfg.vlan);
        };
        bridgeVLANs = lib.mapAttrsToList (_: x: {
          VLAN = x.vid;
        }) cfg.vlan;
      };
      "40-${cfg.vxlanName}" = {
        name = cfg.vxlanName;
        networkConfig = {
          LinkLocalAddressing = "no";
          Bridge = cfg.bridgeName;
        };
        bridgeConfig = {
          NeighborSuppression = true;
          Learning = false;
          VLANTunnel = true;
        };
        bridgeVLANs = lib.mapAttrsToList (_: x: {
          VLAN = x.vid;
        }) cfg.vlan;
      };
    }
    // lib.concatMapAttrs (
      _: x:
      lib.optionalAttrs x.enableVRF {
        "40-${x.bridgeName}" = {
          name = x.bridgeName;
          networkConfig = {
            LinkLocalAddressing = "no";
            VRF = x.vrfName;
          };
        };
        "40-${x.vrfName}" = {
          name = x.vrfName;
        };
      }
    ) cfg.vlan;

    services.networkd-dispatcher = {
      enable = true;
      extraArgs = [
        "--run-startup-triggers"
      ];
      rules.setup-evpn = {
        onState = [ "configured" ];
        # bridge may report vniEnd, vlanEnd, tunidEnd. Currently, we treat the interface
        # as fully managed by this module, so they cannot happen.
        script = ''
          vxlan_name=${lib.escapeShellArg cfg.vxlanName}
          # shellcheck disable=SC2154
          if [[ $IFACE != "$vxlan_name" || $AdministrativeState != "configured" ]]; then
            exit 0
          fi
          export PATH=${
            lib.makeBinPath [
              pkgs.iproute2
              pkgs.jq
            ]
          }:"$PATH"
          declare -A desired_vni_map=(${
            lib.concatMapStringsSep " " (x: "[${toString x.vni}]=${toString x.vid}") (lib.attrValues cfg.vlan)
          })
          # gather states
          declare -A actual_vnis=() actual_vid_map=()
          while IFS= read -r -d "" vni; do
              actual_vnis[$vni]=1
          done < <(
            bridge -j vni show dev "$vxlan_name" |
            jq -j '.[].vnis[] | "\(.vni)\u0000"'
          )
          while IFS= read -r -d "" vid && IFS= read -r -d "" vni; do
              actual_vid_map[$vid]=$vni
          done < <(
            bridge -j vlan tunnelshow dev "$vxlan_name" |
            jq -j '.[].tunnels[] | "\(.vlan)\u0000\(.tunid)\u0000"'
          )
          # delete old VNIs
          for vni in "''${!actual_vnis[@]}"; do
            if [[ ! -v desired_vni_map[$vni] ]]; then
              echo "Deleting VNI $vni from $vxlan_name"
              bridge vni del dev "$vxlan_name" vni "$vni"
            fi
          done
          # create new VNIs
          for vni in "''${!desired_vni_map[@]}"; do
            if [[ ! -v actual_vnis[$vni] ]]; then
              echo "Creating VNI $vni on $vxlan_name"
              bridge vni add dev "$vxlan_name" vni "$vni"
            fi
          done
          # delete old VLAN tunnels
          for vid in "''${!actual_vid_map[@]}"; do
              vni=''${actual_vid_map[$vid]}
              if [[ ! -v desired_vni_map[$vni] || ''${desired_vni_map[$vni]} != "$vid" ]]; then
                  echo "Deleting VLAN tunnel for VLAN $vid and VNI $vni on $vxlan_name"
                  bridge vlan del dev "$vxlan_name" vid "$vid" tunnel_info id "$vni"
              fi
          done
          # create new VLAN tunnels
          for vni in "''${!desired_vni_map[@]}"; do
              vid=''${desired_vni_map[$vni]}
              if [[ ! -v actual_vid_map[$vid] || ''${actual_vid_map[$vid]} != "$vni" ]]; then
                  echo "Creating VLAN tunnel for VLAN $vid and VNI $vni on $vxlan_name"
                  bridge vlan add dev "$vxlan_name" vid "$vid" tunnel_info id "$vni"
              fi
          done
        '';
      };
    };
  };
}
