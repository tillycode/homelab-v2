{ lib, config, ... }:
let
  primary = "router";
  addresses = {
    hgh0 = "10.112.32.200";
    router = "10.112.10.200";
  };

  inherit (config.system) name;
  address = addresses.${name};
  primaryAddress = addresses.${primary};
  secondaryAddresses = lib.attrValues (lib.filterAttrs (n: a: n != primary) addresses);
in
{
  config = lib.mkMerge [
    (lib.mkIf (name == primary) {
      services.coredns = {
        enable = true;
        config = ''
          (snip) {
            bind ${address}
            errors
            loadbalance
            log
            minimal
            root /etc/coredns/zones
            transfer {
              to ${lib.concatStringsSep " " secondaryAddresses}
            }
          }
          szp15.com {
            import snip
            file szp15.com.zone {
              reload 30s
            }
          }
          szp.io {
            import snip
            file szp.io.zone {
              reload 30s
            }
          }
        '';
      };

      environment.etc."coredns/zones/szp15.com.zone".source = ./szp15.com.zone;
      environment.etc."coredns/zones/szp.io.zone".source = ./szp.io.zone;

      sops.secrets."coredns/secretRecords/szp.io" = { };
      systemd.services.coredns.serviceConfig.LoadCredential = [
        "szp.io:${config.sops.secrets."coredns/secretRecords/szp.io".path}"
      ];
    })
    (lib.mkIf (name != primary) {
      services.coredns = {
        enable = true;
        config = ''
          (snip) {
            bind ${address}
            errors
            loadbalance
            log
            minimal
            secondary {
              transfer from ${primaryAddress}
            }
          }
          szp15.com {
            import snip
          }
          szp.io {
            import snip
          }
        '';
      };
    })
    {
      networking.netns.coredns = {
        inherit address;
        extraStartScript = ''
          resolvectl dns coredns ${address}
          resolvectl domain coredns ~szp.io ~szp15.com
          resolvectl llmnr coredns off
          resolvectl mdns coredns off
          # systemd doesn't set DNS when the interface doesn't has an IP address.
          ip address add 169.254.23.1/32 dev coredns
        '';
      };

      systemd.services.coredns = {
        bindsTo = [ "netns-coredns.service" ];
        after = [ "netns-coredns.service" ];
        serviceConfig = {
          NetworkNamespacePath = "/var/run/netns/coredns";
        };
      };

      networking.firewall.extraForwardRules = ''
        oifname "coredns" accept
        iifname "coredns" accept
      '';
    }
  ];
}
