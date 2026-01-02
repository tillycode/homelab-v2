{
  self,
  lib,
  inputs,
  ...
}:
let
  mkNode =
    name: cfg:
    let
      inherit (cfg.pkgs.stdenv.hostPlatform) system;
    in
    {
      hostname = name;
      sshUser = "root";
      profiles.system = {
        path = inputs.deploy-rs.lib.${system}.activate.nixos cfg;
      };
    };
  nodes = lib.mapAttrs mkNode self.nixosConfigurations;
in
{
  flake.deploy = { inherit nodes; };
}
