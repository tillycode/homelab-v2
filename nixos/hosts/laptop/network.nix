{
  profiles.sing-box.tailscale = {
    routeDNS = true;
    routes = [
      "10.112.0.0/16"
    ];
  };
}
