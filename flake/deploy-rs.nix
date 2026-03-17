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
      hostname =
        if lib.hasSuffix "-vm" name then
          "${lib.removeSuffix "-vm" name}.vm.szp.io"
        else
          "${name}.nodes.szp.io";
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
