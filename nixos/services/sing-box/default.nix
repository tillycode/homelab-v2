{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.sing-box;
  tunMark = "0x2023";
  bypassMark = "0x2024";
  tunAddressV4 = "172.19.0.1";
  tunAddressV6 = "fdfe:dcba:9876::1";
  resolverAddress = "fdfe:3c59:ba97:1::1";
  dnsHijacks = lib.filter (dns: dns.addresses != [ ]) [
    {
      family = "ip";
      tag = "dns-intercept-v4";
      listen = tunAddressV4;
      target = tunAddressV4;
      addresses = lib.filter (address: !lib.hasInfix ":" address) cfg.hijackDNSAddresses;
    }
    {
      family = "ip6";
      tag = "dns-intercept";
      listen = tunAddressV6;
      target = "[${tunAddressV6}]";
      addresses = lib.filter (lib.hasInfix ":") cfg.hijackDNSAddresses;
    }
  ];
  dnsAddresses = dns: "{ ${lib.concatStringsSep ", " dns.addresses} }";
  dnsMatch = dns: "${dns.family} daddr ${dnsAddresses dns} meta l4proto { tcp, udp } th dport 53";
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
  options.profiles.sing-box = {
    hijackDNSAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ resolverAddress ];
      description = "Destination IP addresses for TCP and UDP DNS interception.";
    };

    proxyInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Interfaces whose incoming traffic is eligible for transparent proxying.
        IPv6 destinations routed through these interfaces bypass the proxy.
        DNS interception is configured separately.
      '';
    };
  };

  config = {

    ## -------------------------------------------------------------------------
    ## CONFIGURATION
    ## -------------------------------------------------------------------------
    services.sing-box = {
      enable = true;
      package = pkgs.sing-box.overrideAttrs (oldAttrs: {
        preBuild =
          assert lib.assertMsg (!oldAttrs ? preBuild) "sing-box should not have preBuild defined";
          ''
            patch -p1 < ${./disable-netfilter-setup.patch}
            pushd vendor/github.com/sagernet/sing-tun
            chmod -R u+w .
            patch -p1 < ${./disable-netfilter-setup-tun.patch}
            popd
          '';
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
            dashboard = {
              enabled = true;
              path = "${pkgs.sing-box-dashboard}";
            };
          }
        ];
        dns = {
          reverse_mapping = true;
          final = "unbound";
          servers = [
            {
              tag = "unbound";
              type = "udp";
              server = resolverAddress;
              server_port = 53;
            }
            {
              tag = "alidns";
              type = "udp";
              server = "223.5.5.5";
              server_port = 53;
            }
          ];
        };
        inbounds = [
          {
            type = "tun";
            interface_name = "sing0";
            address = [
              "${tunAddressV4}/30"
              "${tunAddressV6}/126"
            ];
            dns_mode = "disabled";
            udp_mapping = "address_and_port_dependent";

            auto_route = true;
            auto_redirect = true;
            auto_redirect_input_mark = tunMark;
            auto_redirect_output_mark = bypassMark;
            route_exclude_address_set = [
              "geoip-private"
              "geoip-server"
            ];

            disable_netfilter_setup = true;
            auto_redirect_port = config.ports.sing-box-redirect;
          }
        ]
        ++ map (dns: {
          type = "direct";
          inherit (dns) tag listen;
          listen_port = config.ports.sing-box-dns;
        }) dnsHijacks;
        outbounds = [
          {
            tag = "direct";
            type = "direct";
          }
          # more outbounds are added via sops
        ];
        route = {
          default_domain_resolver = "alidns";
          final = "Proxy";
          rules = [
            (lib.mkIf (dnsHijacks != [ ]) {
              inbound = map (dns: dns.tag) dnsHijacks;
              action = "hijack-dns";
            })
            {
              ip_cidr = "fd57:b9d9:4a63::1/128";
              outbound = "lax0";
            }
            {
              ip_cidr = "fd57:b9d9:4a63::2/128";
              outbound = "hkg0";
            }
            {
              ip_cidr = "fd57:b9d9:4a63::3/128";
              outbound = "hkg1";
            }
            {
              ip_cidr = [
                "223.5.5.5/32"
                "119.29.29.29/32"
              ];
              action = "bypass";
              outbound = "direct";
            }
          ]
          ++ [
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
              network = "udp";
              port = 443;
              action = "reject";
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
        ExecStartPost = pkgs.writeScript "sing-box.nftable" ''
          #!${lib.getExe pkgs.nftables} -f
          define redirect_port = ${toString config.ports.sing-box-redirect}
          define dns_port = ${toString config.ports.sing-box-dns}
          define tun_mark = ${tunMark}
          define bypass_mark = ${bypassMark}
          define reset_mark = 0x2025

          destroy table inet sing-box
          table inet sing-box {
            set proxy_interfaces {
              type ifname
              ${lib.optionalString (cfg.proxyInterfaces != [ ]) ''
                elements = { ${lib.concatMapStringsSep ", " builtins.toJSON cfg.proxyInterfaces} }
              ''}
            }

            set excluded_v4 {
              type ipv4_addr
              flags interval
              elements = {
                0.0.0.0/8,
                10.0.0.0/8,
                47.96.0.0/15,
                87.83.107.0/24,
                100.64.0.0/10,
                127.0.0.0/8,
                169.254.0.0/16,
                172.16.0.0/12,
                185.218.4.0/22,
                192.168.0.0/16,
                194.104.147.128/26,
                209.209.59.0/24,
                224.0.0.0/4
              }
            }

            set excluded_v6 {
              type ipv6_addr
              flags interval
              elements = {
                ::/127,
                2408:4005::/33,
                fc00::/7,
                fe80::/10,
                ff00::/8
              }
            }

            chain bypass_proxy {
              ${lib.concatMapStringsSep "\n    " (dns: "${dnsMatch dns} counter accept") dnsHijacks}
              fib daddr type local counter accept
              ip daddr @excluded_v4 counter accept
              ip6 daddr @excluded_v6 counter accept
            }

            chain bypass_prerouting {
              iifname != @proxy_interfaces counter accept
              meta nfproto ipv6 fib daddr oifname @proxy_interfaces counter accept
            }

            chain bypass_output {
              meta nfproto ipv6 oifname @proxy_interfaces counter accept
            }

            chain prematch {
              ct direction reply return
              meta mark { $bypass_mark, $tun_mark } ct mark set meta mark return
              ct mark { $bypass_mark, $tun_mark } meta mark set ct mark return
              meta l4proto != { icmp, tcp, udp, ipv6-icmp } return
              meta l4proto tcp meta mark $reset_mark counter reject with tcp reset

              tcp flags & (syn | ack) != syn return
              ct state != new return
              jump bypass_proxy
              meta l4proto { tcp, udp } counter queue flags bypass to 100
              icmp type echo-request icmp code 0 counter queue flags bypass to 100
              icmpv6 type echo-request icmpv6 code 0 counter queue flags bypass to 100
            }

            chain redirect_dns {
              ct direction reply accept
              meta mark { $bypass_mark, $tun_mark } counter accept
              ${lib.concatMapStringsSep "\n    " (
                dns: "${dnsMatch dns} counter dnat ${dns.family} to ${dns.target}:$dns_port"
              ) dnsHijacks}
            }

            chain redirect_tcp {
              meta l4proto != tcp counter accept
              jump bypass_proxy
              tcp option mptcp exists counter drop
              meta l4proto tcp counter dnat ip to ${tunAddressV4}:$redirect_port
              meta l4proto tcp counter dnat ip6 to [${tunAddressV6}]:$redirect_port
            }

            chain route_udp_icmp {
              ct direction reply accept
              meta l4proto != { icmp, udp, ipv6-icmp } counter accept
              meta mark { $bypass_mark, $tun_mark } counter accept
              jump bypass_proxy
              meta mark set $tun_mark ct mark set meta mark counter accept
            }

            chain prerouting_prematch {
              type filter hook prerouting priority dstnat - 1; policy accept;
              jump bypass_prerouting
              jump prematch
            }

            chain output_prematch {
              type route hook output priority mangle + 1; policy accept;
              jump bypass_output
              jump prematch
            }

            chain prerouting {
              type nat hook prerouting priority dstnat + 2; policy accept;
              jump redirect_dns
              jump bypass_prerouting
              jump redirect_tcp
            }

            chain output {
              type nat hook output priority mangle + 2; policy accept;
              jump redirect_dns
              jump bypass_output
              jump redirect_tcp
            }

            chain prerouting_udp_icmp {
              type filter hook prerouting priority dstnat + 3; policy accept;
              jump bypass_prerouting
              jump route_udp_icmp
            }

            chain output_udp_icmp {
              type route hook output priority mangle + 3; policy accept;
              jump bypass_output
              jump route_udp_icmp
            }
          }
        '';
        ExecStopPost = "${lib.getExe pkgs.nftables} destroy table inet sing-box";
      };
    };

    systemd.network.networks."40-sing0" = {
      name = "sing0";
      linkConfig.ActivationPolicy = "manual";
      networkConfig = {
        KeepConfiguration = "static";
        IPv6AcceptRA = false;
      };
      routes = [
        {
          Gateway = "172.19.0.2";
          Table = 2022;
        }
        {
          Gateway = "fdfe:dcba:9876::2";
          Table = 2022;
        }
      ];
      routingPolicyRules = [
        {
          To = "fd57:b9d9:4a63::/64";
          IPProtocol = "udp";
          SourcePort = 4500;
          DestinationPort = 4500;
          Table = 2022;
          Priority = 8999;
        }
        {
          FirewallMark = tunMark;
          Table = 2022;
          Priority = 9001;
          Family = "both";
        }
      ];
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
    networking.firewall.extraInputRules = ''
      ct status dnat tcp dport { ${toString config.ports.sing-box-redirect}, ${toString config.ports.sing-box-dns} } accept
      ct status dnat udp dport ${toString config.ports.sing-box-dns} accept
    '';
    networking.firewall.extraForwardRules = ''
      oifname "sing0" accept
    '';
    networking.firewall.extraReversePathFilterRules = ''
      iifname "sing0" ct state { established, related } accept
    '';
  };
}
