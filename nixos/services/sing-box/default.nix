{ pkgs, config, ... }:
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
in
{
  imports = [ ./networking.nix ];

  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.sing-box = {
    enable = true;
    settings = {
      log.level = "warn";
      experimental = {
        clash_api = {
          default_mode = "Enhanced";
          external_controller = "0.0.0.0:9090";
          external_ui = pkgs.metacubexd;
          # the secret is added via sops
        };
        cache_file = {
          enabled = true;
          path = "/var/lib/sing-box/cache.db";
          store_dns = true;
        };
      };
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
        ];
        rules = [
          {
            domain_suffix = [
              "szp.io"
              "szp15.com"
            ];
            server = "local";
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
          netns = "sing-box";
          address = [
            "172.19.0.1/30"
            "fdfe:dcba:9876::1/126"
          ];
          dns_mode = "disabled";

          auto_route = true;
          auto_redirect = true;
        }
      ];
      outbounds = [
        {
          tag = "direct";
          type = "direct";
        }
        # more outbounds are added via sops
      ];
      route = {
        default_domain_resolver = "local";
        final = "Proxy";
        rules = [
          {
            ip_cidr = [ "172.19.0.2/32" ];
            network = [
              "tcp"
              "udp"
            ];
            port = 53;
            action = "hijack-dns";
          }
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
            action = "route";
            rule_set = [
              "geosite-openai"
              "geosite-anthropic"
              "geosite-google-gemini"
            ];
            outbound = "US";
          }
          {
            network = "icmp";
            action = "reject";
            method = "reply";
          }
        ];
        rule_set = [
          (mkGeoipRuleSet "geoip-cn")
          (mkGeositeRuleSet "geosite-geolocation-cn")
          (mkGeositeRuleSet "geosite-geolocation-!cn")
          (mkGeositeRuleSet "geosite-openai")
          (mkGeositeRuleSet "geosite-anthropic")
          (mkGeositeRuleSet "geosite-google-gemini")
        ];
      };
      network_namespaces = [
        {
          type = "unshare";
          tag = "sing-box";
          pid_file = "/run/sing-box/netns.pid";
        }
      ];
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
      RestrictNamespaces = [
        "user"
        "net"
      ];
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
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

  ## ---------------------------------------------------------------------------
  ## PERSISTENCE
  ## ---------------------------------------------------------------------------
  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/private/sing-box";
      mode = "0700";
    }
  ];

  ## ---------------------------------------------------------------------------
  ## SECRETS
  ## ---------------------------------------------------------------------------
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

}
