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
        config.bbr
        config.home-manager
        config.preservation
        config.sops
        networking.firewall
        networking.networkd
        programs.nix
        programs.tools
        services.nix-gc
        services.nix-optimise
        services.sshd
        system.nixos-init
        system.zram
      ];
      suites.server = suites.base ++ [
        programs.minimal
      ];
      suites.hasee = suites.server ++ [
        hosts.hasee
        services.ntp-home
        services.rke2-hasee.server
        system.disko
        system.systemd-boot
      ];

      nixos.hasee01 = suites.hasee;
      nixos.hasee02 = suites.hasee;
      nixos.hasee03 = suites.hasee;
      nixos.router = suites.server ++ [
        hosts.router
        networking.wireguard
        services.chrony
        services.coredns
        services.sing-box
        system.disko
        system.systemd-boot
      ];

      nixos.hgh0 = suites.server ++ [
        hosts.hgh0
        networking.wireguard
        services.coredns
        services.haproxy
        services.sing-box
        system.disko
        system.systemd-boot
      ];
    }
  );

  homeProfiles = (self.lib.listModules ../home-manager);

  nixosModules = lib.attrValues self.nixosModules ++ [
    inputs.preservation.nixosModules.default
    inputs.disko.nixosModules.default
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.default
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
        {
          lib,
          self,
          ...
        }:
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
        systemd.network.networks."40-svc".address = [ "10.112.8.2/24" ];
      };
    })
    (mkHost {
      name = "hasee02";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-svc".address = [ "10.112.8.3/24" ];
      };
    })
    (mkHost {
      name = "hasee03";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-svc".address = [ "10.112.8.4/24" ];
      };
    })
    (mkHost {
      name = "router";
      system = "x86_64-linux";
    })
    (mkHost {
      name = "hgh0";
      system = "x86_64-linux";
    })
  ];

  flake.passthru = {
    nixosProfiles = profiles;
  };
}
