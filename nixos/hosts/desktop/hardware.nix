{ pkgs, config, ... }:
{
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;

  programs.nix-ld.libraries = [
    # for pytorch
    config.hardware.nvidia.package
  ];
}
