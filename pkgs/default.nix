{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) newScope lib nix-update-script;
  callPackage = newScope {
    # doesn't override pkgs's nix-update-script
    nix-update-script =
      args: nix-update-script (args // { extraArgs = [ "-F" ] ++ args.extraArgs or [ ]; });
  };
in
{
  inherit (callPackage ./rke2 { })
    rke2_1_34
    ;
  devPackages = lib.recurseIntoAttrs (callPackage ./dev-packages { });
  sing-box = callPackage ./sing-box.nix { };
}
