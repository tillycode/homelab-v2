{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      pantum-driver
    ];
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
