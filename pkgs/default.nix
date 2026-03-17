{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) newScope lib nix-update-script;
  extra = {
    # doesn't override pkgs's nix-update-script
    nix-update-script =
      args: nix-update-script (args // { extraArgs = [ "-F" ] ++ args.extraArgs or [ ]; });
  };
in
lib.makeScope (self: newScope (extra // self)) (self: {
  rke2 = self.callPackage ./rke2 { };
  zteonu = self.callPackage ./zteonu.nix { };
  dnsfmt = self.callPackage ./dnsfmt.nix { };
  devPackages = lib.recurseIntoAttrs (self.callPackage ./dev-packages { });
  images = lib.recurseIntoAttrs (self.callPackage ./images { });
  vault-plugin-secrets-github = self.callPackage ./vault-plugin-secrets-github.nix { };
})
