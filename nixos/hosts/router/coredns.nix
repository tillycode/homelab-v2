{
  services.coredns = {
    enable = true;
    config = ''
      (snip) {
        bind 10.112.10.200
        errors
        loadbalance
        log
        minimal
        root /etc/coredns/zones
        transfer {
          to 10.112.32.200 *
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

  networking.netns.coredns = {
    address = "10.112.10.200";
    extraStartScript = ''
      resolvectl dns coredns 10.112.10.200
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
    iifname {"lan", "svc", "wg0"} oifname "coredns" accept
    iifname "coredns" oifname {"wg0"} accept
  '';

  environment.etc."coredns/zones/szp15.com.zone".source = ./szp15.com.zone;
  environment.etc."coredns/zones/szp.io.zone".source = ./szp.io.zone;
}
