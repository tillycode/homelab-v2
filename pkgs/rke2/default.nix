{
  lib,
  callPackage,
  path,
  ...
}@args:
let
  extraArgs = builtins.removeAttrs args [
    "callPackage"
    "path"
  ];
  common =
    opts:
    callPackage (import "${path}/pkgs/applications/networking/cluster/rke2/builder.nix" lib
      opts
    ) extraArgs;
in
{
  rke2_1_34 = common (
    (import ./1_34/versions.nix)
    // {
      updateScript = null;
      # updateScript = [
      #   ./update-script.sh
      #   "34"
      # ];
    }
  );
}
