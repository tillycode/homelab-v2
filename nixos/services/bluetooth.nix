{
  hardware.bluetooth.enable = true;
  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/bluetooth";
      mode = "0700";
    }
  ];
}
