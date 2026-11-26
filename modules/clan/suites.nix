{ config, ... }:
{
  # TODO: we should use a descriptive way to manage suites
  flake.clan.inventory.instances.nixos-base-module = {
    module.name = "importer";
    roles.default.tags = [ "all" ];
    roles.default.extraModules = [
      config.flake.modules.nixos.base
    ];
  };
}
