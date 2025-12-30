{
  inputs,
  self,
  getSystem,
  lib,
  ...
}:
let
  profiles = self.lib.listModules ../nixos // {
    suites = with profiles; {
      base = [
        boot.nixos-init
        networking.networkd
      ];
      server = [
        suites.base

        programs.minimal
        networking.bbr
      ];
      desktop = [
        suites.base
      ];
    };
  };

  nixosModules = lib.attrValues self.nixosModules ++ [
    inputs.preservation.nixosModules.default
    inputs.disko.nixosModules.default
  ];
  nixosSpecialArgs = {
    inherit inputs self profiles;
  };

  mkHost =
    {
      name,
      system ? throw "system is required",
      profiles ? [ ],
      module ? { },

      nixpkgs ? inputs.nixpkgs,
      specialArgs ? nixosSpecialArgs,
      commonModules ? nixosModules,
      pkgs ? (getSystem system).allModuleArgs.pkgs,
    }:
    let
      defaultModule =
        { lib, self, ... }:
        {
          imports = [
            nixpkgs.nixosModules.readOnlyPkgs
          ]
          ++ self.lib.mkImports profiles;

          networking.hostName = lib.mkDefault name;
          nixpkgs.pkgs = lib.mkDefault pkgs;
        };
    in
    {
      ${name} = nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        modules = commonModules ++ [
          module
          defaultModule
        ];
      };
    };
in
{
  flake.nixosConfigurations = lib.mkMerge [
    (mkHost {
      name = "hasee01";
      system = "x86_64-linux";
      profiles = with profiles; [
        suites.server

        boot.systemd-boot
        hosts.hasee
      ];
      module =
        { pkgs, ... }:
        {
          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            initialPassword = "nixos";
          };
          environment.systemPackages = with pkgs; [
            htop
          ];
          system.stateVersion = "25.11";
        };
    })
  ];
}
