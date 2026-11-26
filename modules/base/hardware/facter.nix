{
  nixpkgs.overlays = [
    (final: prev: {
      nixos-facter = prev.nixos-facter.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches or [ ] ++ [
          # eliminate false-positive hardware network interfaces.
          ./ignore-virtual-interface.patch
        ];
      });

      hwinfo = prev.hwinfo.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches or [ ] ++ [
          # see https://github.com/openSUSE/hwinfo/pull/195.
          # fix uninitialized variables in hwinfo, causing `tlb_size` to be unreproducible.
          (final.fetchpatch {
            url = "https://github.com/sunziping2016/hwinfo/commit/5e727804cffb983a06e6b43161edf6017d320c5a.patch";
            hash = "sha256-NXVZSbq8JCpy/xR6Z8/pm+pudMnT231+TVb/zjQP1wA=";
          })
        ];
      });
    })
  ];

  flake.modules.nixos.base = {
    hardware.facter.detected.dhcp.enable = false;
  };
}
