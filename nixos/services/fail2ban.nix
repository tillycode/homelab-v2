{
  services.fail2ban.enable = true;

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/fail2ban";
    }
  ];
}
