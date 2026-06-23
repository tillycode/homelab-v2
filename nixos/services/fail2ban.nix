{
  services.fail2ban = {
    enable = true;
    banaction = "nftables-multiport[blocktype=DROP]";
    banaction-allports = "nftables-allports[blocktype=DROP]";
  };

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/fail2ban";
    }
  ];
}
