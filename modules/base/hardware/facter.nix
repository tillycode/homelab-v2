{
  nixpkgs.overlays = [
    (final: prev: {
      # Eliminate false-positive hardware network interfaces.
      nixos-facter = prev.nixos-facter.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches or [ ] ++ [
          ./ignore-virtual-interface.patch
        ];
      });
    })
  ];

  flake.modules.nixos.base = {
    hardware.facter.detected.dhcp.enable = false;
  };
}
