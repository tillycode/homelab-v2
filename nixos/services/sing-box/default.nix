{
  pkgs,
  config,
  lib,
  ...
}:
let
  mkGeoipRuleSet = name: {
    tag = name;
    type = "local";
    path = "${pkgs.sing-geoip}/share/sing-box/rule-set/${name}.srs";
  };
  mkGeositeRuleSet = name: {
    tag = name;
    type = "local";
    path = "${pkgs.sing-geosite}/share/sing-box/rule-set/${name}.srs";
  };
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.profiles.sing-box;
in
{
  options.profiles.sing-box.tailscale = {
    enable = mkEnableOption "Enable sing-box tailscale" // {
      default = true;
    };
    routeDNS = mkEnableOption "Route DNS to tailscale";
    routes = mkOption {
      type = types.listOf types.str;
      description = "Routes to tailscale";
      default = [ ];
    };
    advertiseRoutes = mkOption {
      type = types.listOf types.str;
      description = "Advertise routes to tailscale";
      default = [ ];
    };
  };

  config = {

    ## -------------------------------------------------------------------------
    ## CONFIGURATION
    ## -------------------------------------------------------------------------
    services.sing-box = {
      enable = true;
      package = pkgs.sing-box.overrideAttrs (oldAttrs: {
        goModules = oldAttrs.goModules.overrideAttrs (oldAttrs: {
          postInstall = (oldAttrs.postInstall or "") + ''
            patch -d "$out" -p2 < ${./prerouting-udp-icmp-exclude.patch}
          '';
        });
        vendorHash = "sha256-tpWr+s7r8eQWeXsJfSiFYwwoSypGkVqfBpfXF5Xn1FQ=";
      });
      settings = {
        log.level = "warn";
        experimental = {
          clash_api = {
            default_mode = "Enhanced";
            external_controller = "127.0.0.1:${toString config.ports.sing-box-clash-api}";
            external_ui = pkgs.metacubexd;
          };
          cache_file = {
            enabled = true;
            path = "/var/lib/sing-box/cache.db";
            store_dns = true;
          };
        };
        services = [
          {
            type = "api";
            listen_port = config.ports.sing-box-api;
            dashboard.enabled = true;
          }
        ];
        dns = {
          reverse_mapping = true;
          final = "remote";
          servers = [
            {
              tag = "local";
              type = "local";
            }
            {
              tag = "remote";
              type = "tls";
              server = "8.8.8.8";
              detour = "Proxy";
            }
          ]
          ++ lib.optional cfg.tailscale.enable (
            {
              tag = "private";
              type = "udp";
              server = "10.112.35.3";
            }
            // lib.optionalAttrs cfg.tailscale.routeDNS {
              detour = "tailscale";
            }
          );
          rules = [
            {
              domain_suffix = [
                "szp.io"
                "szp15.com"
              ];
              server = "private";
            }
            {
              rule_set = "geosite-geolocation-cn";
              server = "local";
            }
            {
              action = "evaluate";
              server = "local";
            }
            {
              type = "logical";
              mode = "and";
              rules = [
                {
                  rule_set = "geosite-geolocation-!cn";
                  invert = true;
                }
                {
                  match_response = true;
                  rule_set = "geoip-cn";
                }
              ];
              server = "local";
            }
          ];
        };
        inbounds = [
          {
            type = "tun";
            interface_name = "sing0";
            address = [
              "172.19.0.1/30"
              "fdfe:dcba:9876::1/126"
            ];
            dns_mode = "disabled";

            auto_route = true;
            auto_redirect = true;
            route_exclude_address_set = [
              "geoip-private"
              "geoip-server"
            ];
          }
        ];
        outbounds = [
          {
            tag = "direct";
            type = "direct";
          }
          # more outbounds are added via sops
        ];
        endpoints = lib.optional cfg.tailscale.enable {
          type = "tailscale";
          tag = "tailscale";
          control_url = "https://tailnet.szp15.com";
          accept_routes = true;
          advertise_routes = cfg.tailscale.advertiseRoutes;
        };
        route = {
          default_domain_resolver = "local";
          final = "Proxy";
          rules = [
            {
              ip_cidr = [
                "172.19.0.2/32"
                "fdfe:dcba:9876::2/128"
              ];
              network = [
                "tcp"
                "udp"
              ];
              port = 53;
              action = "hijack-dns";
            }
          ]
          ++ lib.optional (cfg.tailscale.enable && cfg.tailscale.routes != [ ]) {
            ip_cidr = cfg.tailscale.routes;
            outbound = "tailscale";
          }
          ++ lib.optional (cfg.tailscale.enable && cfg.tailscale.advertiseRoutes != [ ]) {
            inbound = "tailscale";
            ip_cidr = cfg.tailscale.advertiseRoutes;
            outbound = "direct";
          }
          ++ lib.optional cfg.tailscale.enable {
            inbound = "tailscale";
            action = "reject";
            method = "drop";
          }
          ++ [
            {
              network = "udp";
              port = 443;
              action = "reject";
            }
            {
              domain_suffix = [
                "byr.pt"
              ];
              outbound = "Proxy";
            }
            {
              rule_set = "geosite-geolocation-cn";
              action = "bypass";
              outbound = "direct";
            }
            {
              type = "logical";
              mode = "and";
              rules = [
                {
                  rule_set = "geoip-cn";
                }
                {
                  rule_set = "geosite-geolocation-!cn";
                  invert = true;
                }
              ];
              action = "bypass";
              outbound = "direct";
            }
            {
              network = "icmp";
              action = "reject";
              method = "reply";
            }
            {
              # to populate domain for accurate routing decisions
              action = "sniff";
              sniffer = [
                "http"
                "tls"
              ];
            }
            {
              action = "route";
              rule_set = [
                "geosite-openai"
                "geosite-anthropic"
                "geosite-google-gemini"
              ];
              outbound = "US";
            }
            {
              action = "route";
              domain_suffix = [
                # speed up cache downloads
                "cache.nixos.org"
              ];
              outbound = "US";
            }
          ];
          rule_set = [
            (mkGeoipRuleSet "geoip-cn")
            (mkGeositeRuleSet "geosite-geolocation-cn")
            (mkGeositeRuleSet "geosite-geolocation-!cn")
            (mkGeositeRuleSet "geosite-openai")
            (mkGeositeRuleSet "geosite-anthropic")
            (mkGeositeRuleSet "geosite-google-gemini")
            {
              tag = "geoip-private";
              type = "inline";
              rules = [
                {
                  ip_cidr = [
                    # private
                    "10.0.0.0/8"
                    "172.16.0.0/12"
                    "192.168.0.0/16"
                    "fc00::/7"
                    # loopback
                    "127.0.0.0/8"
                    "::1/128"
                    # multicast
                    "224.0.0.0/4"
                    "ff00::/8"
                    # link-local unicast
                    "169.254.0.0/16"
                    "fe80::/10"
                    # interface local multicast
                    "ff01::/16"
                    # CGNAT
                    "100.64.0.0/10"
                    # unspecified
                    "0.0.0.0/8"
                    "::/128"
                  ];
                }
              ];
            }
            {
              tag = "geoip-server";
              type = "inline";
              rules = [
                {
                  ip_cidr = [
                    "87.83.107.0/24"
                    "194.104.147.128/26"
                    "185.218.4.0/22"
                    "209.209.59.0/24"
                    "47.96.0.0/15"
                    "2408:4005::/33"
                  ];
                }
              ];
            }
          ];
        };
      };
    };

    systemd.services.sing-box = {
      preStart = ''
        ln -sf "$CREDENTIALS_DIRECTORY/outbounds.json" /run/sing-box/zoutbounds.json
      '';
      serviceConfig = {
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        DynamicUser = true;
        PrivateDevices = true;
        DeviceAllow = [ "/dev/net/tun" ];
        BindReadOnlyPaths = [ "/dev/net/tun" ];
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = [
          ""
          "CAP_NET_ADMIN"
        ];
        AmbientCapabilities = [
          ""
          "CAP_NET_ADMIN"
        ];
        LoadCredential = "outbounds.json:${config.sops.secrets."sing-box/outbounds.json".path}";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_NETLINK"
          "AF_INET"
          "AF_INET6"
        ];
        SystemCallFilter = "@system-service";
        SystemCallArchitectures = "native";
      };
    };

    systemd.network.networks."40-sing0" = {
      name = "sing0";
      linkConfig.ActivationPolicy = "manual";
      networkConfig = {
        DNS = "172.19.0.2";
        Domains = "~.";
        KeepConfiguration = "static";
        DNSDefaultRoute = false;
        IPv6AcceptRA = false;
      };
      routes = lib.optionals cfg.tailscale.enable (
        lib.map (x: {
          Destination = x;
        }) cfg.tailscale.routes
      );

    };
    systemd.network.config.networkConfig = {
      ManageForeignRoutes = false;
      ManageForeignRoutingPolicyRules = false;
    };

    environment.variables.BOX_API_URL = (
      toString "http://127.0.0.1:${toString config.ports.sing-box-api}"
    );

    ## -------------------------------------------------------------------------
    ## PERSISTENCE
    ## -------------------------------------------------------------------------
    preservation.preserveAt.default.directories = [
      {
        directory = "/var/lib/private/sing-box";
        mode = "0700";
      }
    ];

    ## -------------------------------------------------------------------------
    ## SECRETS
    ## -------------------------------------------------------------------------
    sops.genSecrets."sing-box/outbounds.json" = {
      script = [
        "${pkgs.devPackages.scripts.editable}/bin/proxy-keydrv"
        "--config"
        (toString (
          pkgs.writeText "config.json" (
            builtins.toJSON {
              extra_groups = [
                {
                  tag = "Proxy";
                  type = "selector";
                  outbounds = [ "All - UrlTest" ];
                }
                {
                  tag = "All - UrlTest";
                  type = "urltest";
                }
                {
                  tag = "US";
                  type = "selector";
                  filter = "^美国";
                }
              ];
            }
          )
        ))
        "--name"
        "me@szp.io"
        "gen-client"
      ];
      input = "proxy/settings.yaml";
    };
    sops.secrets."sing-box/outbounds.json" = {
      restartUnits = [ "sing-box.service" ];
    };

    ## ---------------------------------------------------------------------------
    ## FIREWALL
    ## ---------------------------------------------------------------------------
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.tailscale.enable [ 41641 ];
    networking.firewall.extraInputRules = ''
      ct status & dnat == dnat accept
    '';
    networking.firewall.extraForwardRules = ''
      oifname "sing0" accept
    '';
    networking.firewall.extraReversePathFilterRules = ''
      iifname "sing0" ct state { established, related } accept
    '';
  };
}
