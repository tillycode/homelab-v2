{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) types mkOption;
in
{
  options.networking.netns = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            name = mkOption {
              type = types.str;
              default = name;
              description = "The name of the network namespace.";
            };
            address = mkOption {
              type = types.str;
              description = "The IPv4 address of the endpoint";
            };
            extraStartScript = mkOption {
              type = types.lines;
              default = "";
              description = "Extra start script for the network namespace.";
            };
            extraStopScript = mkOption {
              type = types.lines;
              default = "";
              description = "Extra stop script for the network namespace.";
            };
          };
        }
      )
    );
    default = { };
    description = "Network namespaces";
  };

  config.systemd.services = lib.mapAttrs' (name: cfg: {
    name = "netns-${name}";
    value = {
      path = [ pkgs.iproute2 ];
      script = ''
        ip netns add "$NETNS_NAME"
        ip link add "$NETNS_NAME" address ee:ee:ee:ee:ee:ee type veth \
          peer name eth0 netns "$NETNS_NAME"
        ip netns exec "$NETNS_NAME" ip link set lo up
        ip netns exec "$NETNS_NAME" ip neighbor add 169.254.1.1 lladdr ee:ee:ee:ee:ee:ee dev eth0
        ip netns exec "$NETNS_NAME" ip address add "$NETNS_ADDRESS/32" dev eth0
        ip netns exec "$NETNS_NAME" ip link set eth0 up
        ip netns exec "$NETNS_NAME" ip route add 169.254.1.1 dev eth0 scope link
        ip netns exec "$NETNS_NAME" ip route add default via 169.254.1.1 dev eth0
        ip link set "$NETNS_NAME" up
        ip route add "$NETNS_ADDRESS/32" dev "$NETNS_NAME"
        ${cfg.extraStartScript}
      '';
      postStop = ''
        ${cfg.extraStopScript}
        ip netns delete "$NETNS_NAME" || true
      '';
      environment = {
        NETNS_NAME = cfg.name;
        NETNS_ADDRESS = cfg.address;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  }) config.networking.netns;
}
