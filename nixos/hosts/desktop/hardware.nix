{ pkgs, config, ... }:
{
  boot.initrd.availableKernelModules = [
    "vmd"
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # sudo btrfs inspect-internal map-swapfile /swap/swapfile
  boot.kernelParams = [
    "resume_offset=533760"
    "intel_iommu=on"
  ];
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 8192;
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;

  programs.nix-ld.libraries = [
    # for pytorch
    config.hardware.nvidia.package
  ];
}
