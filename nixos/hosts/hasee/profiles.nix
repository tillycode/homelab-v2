{
  profiles.system.disko = {
    enableLVM = true;
    devices = [
      "/dev/disk/by-path/pci-0000:02:00.0-nvme-1"
      "/dev/disk/by-path/pci-0000:01:00.0-nvme-1"
    ];
    swapSize = "32G";
    lvmRootType = "raid0";
    lvmRootSize = "512G";
  };
  # FIXME: https://github.com/nix-community/disko/issues/422
  #    disko add extraArgs before the VG positional argument.
  #    Therefore, we have no way to restrict the PV of created LV.
  #    For now, we manually create the LV. The code is left here for reference.
  # disko.devices.lvm_vg.pool.lvs = {
  #   ceph01 = {
  #     size = "512G";
  #     extraArgs = [
  #       "/dev/disk/by-partlabel/disk-main-primary"
  #     ];
  #   };
  #   ceph02 = {
  #     size = "512G";
  #     extraArgs = [
  #       "/dev/disk/by-partlabel/disk-data2-primary"
  #     ];
  #   };
  # };
}
