{ pkgs, ... }: {
  # this should be able to detect by facter
  hardware.cpu.intel.npu.enable = true;
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
}
