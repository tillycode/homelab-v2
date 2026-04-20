let
  ipv4Address = "10.75.0.1";
  ipv4CIDR = "${ipv4Address}/24";
  ipv6CIDR = "fd42:e16c:cbc4:9d5e::1/64";
in
{
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  virtualisation.incus = {
    enable = true;
    ui.enable = true;
    preseed = {
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          project = "default";
          config = {
            "ipv4.address" = ipv4CIDR;
            "ipv6.address" = ipv6CIDR;
            "ipv4.nat" = "true";
            "ipv6.nat" = "true";
          };
        }
      ];
      storage_pools = [
        {
          name = "default";
          driver = "btrfs";
          description = "";
          config = {
            size = "500GiB";
          };
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              type = "nic";
              name = "eth0";
              network = "incusbr0";
            };
            root = {
              type = "disk";
              path = "/";
              pool = "default";
            };
          };
        }
      ];
    };
  };

  ## ---------------------------------------------------------------------------
  ## PERSISTENCE
  ## ---------------------------------------------------------------------------
  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/incus";
      mode = "0711";
    }
  ];

  ## ---------------------------------------------------------------------------
  ## FIREWALL
  ## ---------------------------------------------------------------------------
  networking.firewall.trustedInterfaces = [ "incusbr0" ];
}
