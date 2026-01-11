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
  rke2 = callPackage ./rke2 { };
  devPackages = lib.recurseIntoAttrs (callPackage ./dev-packages { });
}
