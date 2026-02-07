{
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.coredns = {
    enable = true;
    config = ''
      (snip) {
        bind 169.254.23.1
        errors
        loadbalance
        cache
      }
      k8s.szp.io {
        import snip
        forward . 10.112.10.10
      }
    '';
  };

  systemd.network.netdevs."40-coredns" = {
    netdevConfig = {
      Name = "coredns";
      Kind = "dummy";
    };
  };

  systemd.network.networks."40-coredns" = {
    matchConfig.Name = "coredns";
    address = [ "169.254.23.1/32" ];
    networkConfig = {
      Domains = "~k8s.szp.io";
      DNS = "169.254.23.1";
      LinkLocalAddressing = "no";
    };
  };
}
