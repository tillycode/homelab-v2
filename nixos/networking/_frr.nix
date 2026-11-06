{
  lib,
  config,
  self,
  ...
}:
let
  vrfConfig = lib.concatStrings (
    lib.mapAttrsToList (
      _: x:
      lib.optionalString x.enableVRF ''
        vrf ${x.vrfName}
          vni ${toString x.vni}
        exit-vrf
        !
      ''
    ) config.networking.evpn.vlan
  );
  bgpVrfConfig = lib.concatStrings (
    lib.mapAttrsToList (
      _: x:
      lib.optionalString x.enableVRF ''
        router bgp 65000 vrf ${x.vrfName}
         bgp router-id ${config.networking.ipv4Address}
         !
         address-family ipv4 unicast
          redistribute connected
          redistribute kernel
          redistribute static
         exit-address-family
         !
         address-family ipv6 unicast
          redistribute connected
          redistribute kernel
          redistribute static
         exit-address-family
         !
         address-family l2vpn evpn
          advertise ipv4 unicast
          advertise ipv6 unicast
         exit-address-family
        exit
        !
      ''
    ) config.networking.evpn.vlan
  );
  peers = lib.filter (x: x != config.networking.ipv4Address) (
    lib.mapAttrsToList (_: x: x.config.networking.ipv4Address) (
      lib.filterAttrs (_: x: x.config.networking.evpn.enable) self.nixosConfigurations
    )
  );
  peerConfig = lib.concatMapStringsSep "\n" (x: "neighbor ${x} peer-group EVPN") peers;
in
{
  services.frr = {
    bgpd.enable = true;
    config = ''
      ${vrfConfig}
      !
      router bgp 65000
        bgp router-id ${config.networking.ipv4Address}
        no bgp default ipv4-unicast
        !
        neighbor EVPN peer-group
        neighbor EVPN remote-as internal
        neighbor EVPN update-source lo
        ${peerConfig}
        !
        address-family l2vpn evpn
         neighbor EVPN activate
         advertise-all-vni
         advertise-svi-ip
        exit-address-family
      exit
      !
      ${bgpVrfConfig}
    '';
  };

  networking.firewall.allowedTCPPorts = [ 179 ];
}
