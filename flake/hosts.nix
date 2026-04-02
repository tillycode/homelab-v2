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
        config.sudo
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
        services.tpm2-pkcs11
        system.disko
        system.systemd-boot
      ];
      suites.desktop = suites.base ++ [
        config.fonts
        config.timezone
        programs."1password"
        programs.nix-ld
        services.bluetooth
        services.gnome-keyring
        services.iwd
        services.pcscd
        services.pipewire
        services.printing
        services.xfce
        system.userborn-subs
        users.sun
        virtualization.podman
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
      nixos.desktop = suites.desktop ++ [
        hosts.desktop
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

      nixos.kubevm = suites.server ++ [
        hosts.kubevm
        system.disko
      ];
      nixos.ai-vm = nixos.kubevm ++ [
        hosts.ai-vm
        services.openbao-proxy
        users.ai
      ];
    }
  );

  homeProfiles = (self.lib.listModules ../home);

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
    (mkHost {
      name = "kubevm";
      system = "x86_64-linux";
      module = {
        system.stateVersion = lib.trivial.release;
      };
    })
    (mkHost {
      name = "ai-vm";
      system = "x86_64-linux";
    })
    (mkHost {
      name = "desktop";
      system = "x86_64-linux";
    })
  ];

  flake.passthru = {
    nixosProfiles = profiles;
  };
}
