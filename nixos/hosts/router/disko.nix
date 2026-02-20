{
  profiles.disko = {
    enable = true;
    device = "/dev/disk/by-path/pci-0000:05:00.0-nvme-1";
    swapSize = "8G";
  };
  zramSwap.enable = true;
}
