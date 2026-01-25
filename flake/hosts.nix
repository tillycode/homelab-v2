{
  inputs,
  self,
  getSystem,
  lib,
  ...
}:
let
  profiles = (self.lib.listModules ../nixos).extend (
    final: prev: with final; {
      suites.base = [
        boot.nixos-init
        home-manager.common
        environment.preservation
        networking.firewall
        networking.networkd
        programs.nix
        programs.tools
        services.nix-gc
        services.nix-optimise
        services.sshd
      ];
      suites.server = [
        suites.base
        programs.minimal
        networking.bbr
      ];
      suites.desktop = [
        suites.base
      ];
      suites.hasee = [
        suites.server
        boot.systemd-boot
        hosts.hasee
      ];

      nixos.hasee01 = [
        suites.hasee
        services.rke2-hasee.bootstrap
      ];
      nixos.hasee02 = [
        suites.hasee
      ];
      nixos.hasee03 = [
        suites.hasee
      ];
    }
  );

  homeProfiles = (self.lib.listModules ../home-manager);

  nixosModules = lib.attrValues self.nixosModules ++ [
    inputs.preservation.nixosModules.default
    inputs.disko.nixosModules.default
    inputs.home-manager.nixosModules.default
  ];
  nixosSpecialArgs = {
    inherit
      inputs
      self
      profiles
      homeProfiles
      ;
  };

  mkHost =
    {
      name,
      system ? throw "system is required",
      profiles ? specialArgs.profiles.nixos.${name} or [ ],
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
      module = {
        systemd.network.networks."40-bond0".address = [ "10.112.8.2/24" ];
      };
    })
    (mkHost {
      name = "hasee02";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-bond0".address = [ "10.112.8.3/24" ];
      };
    })
    (mkHost {
      name = "hasee03";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-bond0".address = [ "10.112.8.4/24" ];
      };
    })
  ];

  flake.passthru = {
    nixosProfiles = profiles;
  };
}
