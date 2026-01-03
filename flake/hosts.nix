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
        environment.preservation
        networking.networkd
        services.sshd
      ];
      server = [
        suites.base

        programs.minimal
        networking.bbr
      ];
      desktop = [
        suites.base
      ];
      hasee = [
        suites.server

        boot.systemd-boot
        hosts.hasee
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
        suites.hasee
      ];
      module = {
        systemd.network.networks."40-bond0".address = [ "10.9.0.11/24" ];
        system.stateVersion = "25.11";
      };
    })
    (mkHost {
      name = "hasee02";
      system = "x86_64-linux";
      profiles = with profiles; [
        suites.hasee
      ];
      module = {
        systemd.network.networks."40-bond0".address = [ "10.9.0.12/24" ];
        system.stateVersion = "25.11";
      };
    })
    (mkHost {
      name = "hasee03";
      system = "x86_64-linux";
      profiles = with profiles; [
        suites.hasee
      ];
      module = {
        systemd.network.networks."40-bond0".address = [ "10.9.0.13/24" ];
        system.stateVersion = "25.11";
      };
    })
  ];
}
