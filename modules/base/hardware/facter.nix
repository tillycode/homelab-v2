{
  nixpkgs.overlays = [
    (final: prev: {
      nixos-facter = prev.nixos-facter.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches or [ ] ++ [
          # eliminate false-positive hardware network interfaces.
          ./ignore-virtual-interface.patch
          # Apply the upstream formatting change required by the fix on 0.4.4.
          (final.fetchpatch {
            url = "https://github.com/nix-community/nixos-facter/commit/ae7c0d0c19a32b160569cc2aba13a29f11d23985.patch";
            includes = [ "pkg/hwinfo/utils.go" ];
            hash = "sha256-yt7QcaQL57pe/A9O6ycaz6pUXlAWosPw0ct6AsV1fSs=";
          })
          # Fix C array decoding, including SMBIOS group handles.
          (final.fetchpatch {
            url = "https://github.com/nix-community/nixos-facter/commit/532a16ec2e1470380bf70f2eef21905ba0442c45.patch";
            hash = "sha256-v5QaKSy/iOBtMp8vATT/DqIsjb2yM51eDwzdzkT36kU=";
          })
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
