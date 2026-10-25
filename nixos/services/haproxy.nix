{ lib, config, ... }:
let
  cfg = config.profiles.haproxy;
  bindArgs = if cfg.netns == null then "" else "namespace ${cfg.netns}";
in
{
  options.profiles.haproxy = {
    netns = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = {
    services.haproxy = {
      enable = true;
      config = ''
        global
          log /dev/log local0 info

        defaults
          log global
          timeout connect 5s
          timeout client 1m
          timeout server 1m

        frontend tls
          mode tcp
          option tcplog
          bind *:443,[::]:443 ${bindArgs}
          tcp-request inspect-delay 5s
          tcp-request content accept if { req.ssl_hello_type 1 }
          default_backend test

        backend test
          mode tcp
          server default [::1]:8443 check
      '';
    };

    systemd.services.haproxy = lib.mkIf (cfg.netns != null) {
      serviceConfig = {
        AmbientCapabilities = lib.mkForce [
          "CAP_NET_BIND_SERVICE"
          "CAP_SYS_ADMIN"
        ];
      };
    };
  };
}
