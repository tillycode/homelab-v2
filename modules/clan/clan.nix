{ inputs, ... }:
{
  imports = [
    inputs.clan-core.flakeModules.default
  ];

  perSystem = { pkgs, ... }: {
    clan.pkgs = pkgs;
  };
}
