{
  lib,
  callPackage,
  path,
}:
let
  makePackage =
    minorVersion:
    callPackage (import "${path}/pkgs/applications/networking/cluster/rke2/builder.nix" lib (
      import ./1_${minorVersion}/versions.nix
      // {
        updateScript = [
          ./update-script.sh
          minorVersion
        ];
      }
    )) { };
in
makePackage "34"
