{ inputs, lib, ... }:
let
  getPackages = pkgs: (import ../pkgs { inherit pkgs; });
  filterPackage =
    system: package: !package.meta.broken or false && lib.meta.availableOn { inherit system; } package;
  flattenAndFilterPackages =
    system: packages:
    lib.pipe packages [
      (lib.mapAttrsToListRecursiveCond (p: v: !lib.isDerivation v) (
        p: v: lib.nameValuePair (lib.concatStringsSep "/" p) v
      ))
      (lib.filter (x: lib.isDerivation x.value && filterPackage system x.value))
      lib.listToAttrs
    ];
in
{
  perSystem =
    { system, ... }:
    {
      # pkgs has already include the overlay, reimport it to avoid double overlay
      packages = flattenAndFilterPackages system (
        getPackages (import inputs.nixpkgs { inherit system; })
      );
    };

  flake.overlays.default = final: prev: getPackages prev;
}
