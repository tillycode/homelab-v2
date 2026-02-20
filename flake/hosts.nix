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
        services.ntp-home
        services.rke2-hasee.server
      ];

      nixos.hasee01 = suites.hasee;
      nixos.hasee02 = suites.hasee;
      nixos.hasee03 = suites.hasee;
      nixos.router = [
        suites.server
        services.chrony
        boot.systemd-boot
        hosts.router
        services.sing-box
      ];

      nixos.hgh0 = [
        suites.server
        boot.systemd-boot
        hosts.hgh0
        services.sing-box
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
        systemd.network.networks."40-svc".address = [ "10.112.8.2/24" ];
        sops.agePublicKey = "age1etar9rrla2d79jfvmsqdzkag0dtjvzh7xf3zdlc5z3k53k6ncf3qthf8gp";
      };
    })
    (mkHost {
      name = "hasee02";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-svc".address = [ "10.112.8.3/24" ];
        sops.agePublicKey = "age1fgz58ufhqxwvush0k26kajeamd3meh7ufy92vqd4yj9cup0dduls7dv9uc";
      };
    })
    (mkHost {
      name = "hasee03";
      system = "x86_64-linux";
      module = {
        systemd.network.networks."40-svc".address = [ "10.112.8.4/24" ];
        sops.agePublicKey = "age1mg0y7kd0zcggy9ukze4sg2drmaafdrwjs4zzqvzhznzhmhtw3a5serua3g";
      };
    })
    (mkHost {
      name = "router";
      system = "x86_64-linux";
      module = {
        sops.agePublicKey = "age1dtdquu63vrxag5pgs4yrqaarjywuksnw4nz2dq5t44v8tv24cy8qz7yfcn";
      };
    })
    (mkHost {
      name = "hgh0";
      system = "x86_64-linux";
      module = {
        sops.agePublicKey = "age128juh5n7pxuw2ltmw434m4tw7s8vk6t44amfa4dw495rkyeqmfcq4vt0wh";
      };
    })
  ];

  flake.passthru = {
    nixosProfiles = profiles;
  };
}
