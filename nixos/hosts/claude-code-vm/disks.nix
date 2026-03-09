{
  boot.initrd.systemd.repart = {
    enable = true;
    device = "/dev/vda";
  };

  systemd.repart.partitions = {
    "10-root" = {
      Type = "root";
      GrowFileSystem = true;
    };
  };
}
