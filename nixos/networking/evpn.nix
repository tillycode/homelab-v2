{ lib, config, ... }:
let
  toTwoDigitHex =
    n:
    let
      hex = lib.toLower (lib.toHexString n);
    in
    if lib.stringLength hex == 1 then "0${hex}" else hex;
  macAddress = lib.concatMapStringsSep ":" toTwoDigitHex (
    [
      2
      0
    ]
    ++ map lib.toInt (lib.splitString "." config.networking.ipv4Address)
  );
in
{
  imports = [ ./_frr.nix ];

  networking.evpn = {
    enable = true;
    vxlanLocal = config.networking.ipv4Address;
    macAddress = macAddress;
  };

  networking.firewall.allowedUDPPorts = [ config.networking.evpn.vxlanPort ];
}
