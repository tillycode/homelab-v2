{
  self,
  lib,
  getSystem,
  ...
}:
let
  mkNode =
    name: cfg:
    let
      inherit (cfg.pkgs.stdenv.hostPlatform) system;
      inherit ((getSystem system).allModuleArgs) pkgs;
    in
    {
      hostname = name;
      sshUser = "root";
      profiles.system = {
        path = pkgs.deploy-rs.lib.activate.nixos cfg;
      };
    };
  nodes = lib.mapAttrs mkNode self.nixosConfigurations;
in
{
  flake.deploy = { inherit nodes; };
}
