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
        services.rke2-hasee.server
      ];
      nixos.hasee03 = [
        suites.hasee
        services.rke2-hasee.server
      ];
      nixos.router = [
        suites.server
        boot.systemd-boot
        hosts.router
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
          config,
          ...
        }:
        {
          imports = [
            nixpkgs.nixosModules.readOnlyPkgs
          ]
          ++ self.lib.mkImports profiles;

          networking.hostName = lib.mkDefault name;
          nixpkgs.pkgs = lib.mkDefault pkgs;
          sops.defaultSopsFile = lib.mkDefault ../secrets/hosts/${name}.yaml;
          sops.age.sshKeyPaths = [
            "${config.preservation.preserveAt.default.persistentStoragePath}/etc/ssh/ssh_host_ed25519_key"
          ];
          sops.gnupg.sshKeyPaths = [ ];
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
        sops.agePublicKey = "age1ksg30jggegpf9dzf0cpy7023htqjenhl6cf8qnuyffm5d4ay8unqlcrf3y";
      };
    })
    (mkHost {
      name = "hasee02";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-bond0".address = [ "10.112.8.3/24" ];
        sops.agePublicKey = "age1mjutxzwpux0l0l6egyrnrm2z05d4sj03ctny7ts3uvuy0k457g5s6rvtta";
      };
    })
    (mkHost {
      name = "hasee03";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-bond0".address = [ "10.112.8.4/24" ];
        sops.agePublicKey = "age17rgneujcf2f20qys0z5dupymn9y8xgq8v6c7y3ra2zgp2t8h89ks6pw235";
      };
    })
    (mkHost {
      name = "router";
      system = "x86_64-linux";
      module = {
        sops.agePublicKey = "age1dtdquu63vrxag5pgs4yrqaarjywuksnw4nz2dq5t44v8tv24cy8qz7yfcn";
      };
    })
  ];

  flake.passthru = {
    nixosProfiles = profiles;
  };
}
