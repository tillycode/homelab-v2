{
  systemd.network.networks."40-svc" = {
    name = "svc";
    linkConfig.MTUBytes = 9000;
    networkConfig = {
      IPv6AcceptRA = false;

      # trick systemd to think DNS is ready
      # see https://github.com/systemd/systemd/blob/v260.2/src/resolve/resolved-link.c#L695-L734.
      DNS = "fe80::1";
      DNSDefaultRoute = false;
    };
  };
}
