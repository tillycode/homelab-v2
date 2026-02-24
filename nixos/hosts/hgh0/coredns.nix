{
  services.coredns = {
    enable = true;
    config = ''
      (snip) {
        bind 10.112.32.200
        errors
        loadbalance
        log
        minimal
        secondary {
          transfer from 10.112.10.200
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

  networking.netns.coredns = {
    address = "10.112.32.200";
    extraStartScript = ''
      resolvectl dns coredns 10.112.32.200
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
}
