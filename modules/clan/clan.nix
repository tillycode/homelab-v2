{ inputs, ... }:
{
  imports = [
    inputs.clan-core.flakeModules.default
  ];

  perSystem = { pkgs, inputs', ... }: {
    clan.pkgs = pkgs;

    nixpkgs.additionalPackages = {
      inherit (inputs'.clan-core.packages) clan-cli;
    };

    devshells.default.devshell.packages = [
      pkgs.clan-cli
    ];
  };
}
