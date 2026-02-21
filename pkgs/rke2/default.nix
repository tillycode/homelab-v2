{
  lib,
  callPackage,
  path,
}:
(callPackage (import "${path}/pkgs/applications/networking/cluster/rke2/builder.nix" lib (
  import ./versions.nix
  // {
    updateScript = [
      ./update-script.sh
      "35"
    ];
  }
)) { })
