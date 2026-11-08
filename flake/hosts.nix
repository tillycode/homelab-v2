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
        config.nix-cache
        config.preservation
        config.sops
        config.sudo
        networking.firewall
        networking.ipam
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
        programs.stress-cli
        services.ntp-home
        system.disko
        system.systemd-boot
      ];
      suites.desktop = suites.base ++ [
        config.fonts
        config.locale-zh
        config.timezone
        programs."1password"
        programs.nix-ld
        programs.steam
        services.bluetooth
        services.gnome-keyring
        services.incus
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
        networking.discard-routes
        networking.forwarding
        services.unbound
        services.chrony
        services.coredns
        services.fail2ban
        services.ipsec
        services.sing-box
        system.disko
        system.systemd-boot
      ];
      nixos.desktop = suites.desktop ++ [
        hosts.desktop
        system.systemd-boot
      ];
      nixos.laptop = suites.desktop ++ [
        hosts.laptop
        system.disko
        services.unbound
        services.sing-box
        system.systemd-boot
      ];

      nixos.hgh0 = suites.server ++ [
        hosts.hgh0
        networking.discard-routes
        networking.forwarding
        services.bird
        services.blog
        services.coredns
        services.haproxy
        services.headscale
        services.ipsec
        services.nginx
        services.sing-box
        system.disko
        system.systemd-boot
      ];

      nixos.sjc1 = suites.server ++ [
        hosts.sjc1
        networking.forwarding
        services.bird
        services.ipsec
        services.postgresql
        services.niks3
        services.nginx
        system.disko
      ];
      nixos.lax0 = suites.server ++ [
        hosts.lax0
        networking.forwarding
        services.bird
        services.ipsec
        services.nginx
        services.xray-server
        system.disko
      ];
      nixos.hkg0 = suites.server ++ [
        hosts.hkg0
        networking.forwarding
        services.bird
        services.ipsec
        services.nginx
        services.xray-server
        system.disko
      ];
      nixos.hkg1 = suites.server ++ [
        hosts.hkg1
        networking.forwarding
        services.bird
        services.ipsec
        services.nginx
        services.xray-server
        system.disko
      ];
    }
  );

  homeProfiles = (self.lib.listModules ../home);

  nixosModules = lib.attrValues self.nixosModules ++ [
    inputs.preservation.nixosModules.default
    inputs.disko.nixosModules.default
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.default
    inputs.niks3.nixosModules.default
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
    })
    (mkHost {
      name = "hasee02";
      system = "x86_64-linux";
    })
    (mkHost {
      name = "hasee03";
      system = "x86_64-linux";
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
      name = "desktop";
      system = "x86_64-linux";
    })
    (mkHost {
      name = "sjc1";
      system = "x86_64-linux";
    })
    (mkHost {
      name = "laptop";
      system = "x86_64-linux";
    })
    # To make nixos-anywhere work, please turn on swapfile before kexec,
    # and manually turn on zramswap and increase
    # writable nix store size before the disko phase.
    #
    #     mount -o remount,size=70% -t tmpfs tmpfs /nix/.rw-store
    #     modprobe zram
    #     zramctl /dev/zram0 --algorithm zstd --size 800000KiB
    #     mkswap -U clear /dev/zram0
    #     swapon --discard --priority 100 /dev/zram0
    #
    (mkHost {
      name = "lax0";
      system = "x86_64-linux";
    })
    (mkHost {
      name = "hkg0";
      system = "x86_64-linux";
    })
    (mkHost {
      name = "hkg1";
      system = "x86_64-linux";
    })
  ];

  flake.passthru = {
    nixosProfiles = profiles;
  };
}
