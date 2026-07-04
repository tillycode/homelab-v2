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
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.sing-box = {
    enable = true;
    package = pkgs.sing-box.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        # add disable_dns_hijack option
        ./sing-box-disable-dns-hijack.patch
      ];
    });
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
          store_rdrc = true;
        };
      };
      dns = {
        reverse_mapping = true;
        final = "remote";
        servers = [
          {
            tag = "local";
            type = "udp";
            server = "223.5.5.5";
          }
          {
            tag = "remote";
            type = "tls";
            server = "8.8.8.8";
            detour = "Proxy";
          }
          {
            tag = "coredns";
            type = "udp";
            server = "10.112.35.3";
          }
        ];
        rules = [
          {
            domain_suffix = [
              "szp.io"
              "szp15.com"
            ];
            server = "coredns";
          }
          {
            rule_set = "geosite-geolocation-cn";
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
          # Note that pre-match stage doesn't respect the exclude set
          route_exclude_address_set = [
            "geoip-private"
            "geoip-special"
          ];
          # sing-box 1.12.12 will add following route policy rules:
          #
          #   9000:	from all fwmark 0x2024 goto 9002
          #   9001:	from all fwmark 0x2023 lookup 2022
          #   9002:	from all nop
          #
          # The route table "2022" is
          #
          #   default via 172.19.0.2 dev sing0
          #   default via fdfe:dcba:9876::2 dev sing0 metric 1024 pref medium
          #
          # and an nft table "sing-box", it
          # 1. don't touch the packet if
          #    a. its nfmark or ctmark is 0x2024
          #    b. or, its destination matches `!route_address || local_address || route_exclude_address`
          # 2. redirect TCP traffic by destination NAT to a port
          # 3. reroute UDP or ICMP traffic by setting its nfmark and ctmark to 0x2023.
          # It also marks its outbound traffic with 0x2024.
          #
          # To make the stateful firewall happy, we need to
          # 1. add an input rule for TCP traffic
          # 2. add a forward rule for UDP and ICMP traffic
          # 3. add a reverse path rule for inbound UDP and ICMP traffic
          #
          # Here're some related options, we use their default values.
          #
          # iproute2_rule_index = 9000;
          # iproute2_table_index = 2022;
          # auto_redirect_input_mark = "0x2023";
          # auto_redirect_output_mark = "0x2024";

          # Note that sing-box 1.14.0 add `dns_mode = "native"` option,
          # which should function the same.
          disable_dns_hijack = true;

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
        # auto_detect_interface = true;
        final = "Proxy";
        rules = [
          # Note that sniff will always match during the pre-match stage.
          # Therefore, we avoid use sniff action.
          # https://github.com/SagerNet/sing-box/blob/v1.13.12/route/route.go#L520C21-L536
          {
            network = "udp";
            port = 53;
            ip_cidr = [
              "172.19.0.2/32"
              "fdfe:dcba:9876::2/128"
            ];
            action = "hijack-dns";
          }
          {
            network = "udp";
            port = 53;
            action = "route";
            outbound = "direct";
          }
          {
            ip_is_private = true;
            action = "bypass";
            outbound = "direct";
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
          (mkGeositeRuleSet "geosite-cn")
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
                  "0.0.0.0/8"
                  "10.0.0.0/8"
                  "100.64.0.0/10"
                  "127.0.0.0/8"
                  "169.254.0.0/16"
                  "172.16.0.0/12"
                  "192.0.0.0/24"
                  "192.0.2.0/24"
                  "192.88.99.0/24"
                  "192.168.0.0/16"
                  "198.18.0.0/15"
                  "198.51.100.0/24"
                  "203.0.113.0/24"
                  "224.0.0.0/4"
                  # "240.0.0.0/4"
                  # "255.255.255.255/32"
                  "::/128"
                  "::1/128"
                  "fc00::/7"
                  "fe80::/10"
                  # "ff00::/8"
                ];
              }
            ];
          }
          {
            tag = "geoip-special";
            type = "inline";
            rules = [
              {
                ip_cidr = [
                  "87.83.107.0/24"
                  "194.104.147.128/26"
                  "185.218.4.0/22"
                  "209.209.59.0/24"
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
        "~CAP_SYS_PTRACE"
        "~CAP_DAC_READ_SEARCH"
      ];
      LoadCredential = "outbounds.json:${config.sops.secrets."sing-box/outbounds.json".path}";
      RestrictAddressFamilies = [
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
  };
  systemd.network.config.networkConfig = {
    ManageForeignRoutes = false;
    ManageForeignRoutingPolicyRules = false;
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

  ## ---------------------------------------------------------------------------
  ## FIREWALL
  ## ---------------------------------------------------------------------------
  networking.firewall.extraInputRules = ''
    ct status & dnat == dnat accept
  '';
  networking.firewall.extraForwardRules = ''
    oifname "sing0" accept
  '';
  networking.firewall.extraReversePathFilterRules = ''
    iifname "sing0" ct state { established, related } accept
  '';
}
