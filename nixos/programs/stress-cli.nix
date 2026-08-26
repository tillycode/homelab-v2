{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    stress-ng
    linuxPackages.turbostat
    nvme-cli
    lm_sensors
  ];
}
