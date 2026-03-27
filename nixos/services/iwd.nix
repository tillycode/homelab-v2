{
  networking.wireless.iwd.enable = true;
  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/iwd";
      mode = "0700";
    }
  ];
}
