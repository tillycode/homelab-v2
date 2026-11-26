{
  inputs,
  self,
  lib,
  ...
}@args:
let
  profiles = (self.lib.listModules ../nixos).extend (
    final: prev: with final; {
      suites.base = [
        config.acme
        config.bbr
        config.ca
        config.home-manager
        config.nix-cache
        config.preservation
        config.sops
        config.sshd-ca
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
        config.cn-dns
        networking.net-svc
        programs.stress-cli
        services.bird
        services.ntp-home
        services.spire-agent-tpm
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
        config.cn-dns
        networking.discard-routes
        networking.forwarding
        services.bind
        services.bird
        services.chrony
        services.cloudflare-ddns
        services.fail2ban
        services.ipsec
        services.openbao
        services.sing-box
        services.spire-agent-tpm
        services.spire-server
        services.tpm2-pkcs11
        services.unbound
        system.disko
        system.systemd-boot
      ];
      nixos.desktop = suites.desktop ++ [
        hosts.desktop
        config.cn-dns
        networking.net-svc
        services.bird
        services.spire-agent-tpm
        system.systemd-boot
      ];
      nixos.laptop = suites.desktop ++ [
        hosts.laptop
        config.cn-dns
        services.bird
        services.ipsec
        services.sing-box
        services.spire-agent-tpm
        services.unbound
        system.disko
        system.systemd-boot
      ];

      nixos.hgh0 = suites.server ++ [
        hosts.hgh0
        config.cn-dns
        networking.discard-routes
        networking.forwarding
        services.bind
        services.bird
        services.blog
        services.caddy
        services.haproxy
        services.ipsec
        services.sing-box
        services.spire-agent-ssh
        services.unbound
        system.disko
        system.systemd-boot
      ];

      nixos.sjc1 = suites.server ++ [
        hosts.sjc1
        config.global-dns
        networking.forwarding
        services.bind
        services.bird
        services.caddy
        services.ipsec
        services.niks3
        services.postgresql
        services.spire-agent-ssh
        system.disko
      ];
      nixos.lax0 = suites.server ++ [
        hosts.lax0
        networking.forwarding
        config.global-dns
        services.bird
        services.caddy
        services.ipsec
        services.spire-agent-ssh
        services.xray-server
        system.disko
      ];
      nixos.hkg0 = suites.server ++ [
        hosts.hkg0
        config.global-dns
        networking.forwarding
        services.bird
        services.caddy
        services.ipsec
        services.spire-agent-ssh
        services.xray-server
        system.disko
      ];
      nixos.hkg1 = suites.server ++ [
        hosts.hkg1
        config.global-dns
        networking.forwarding
        services.bird
        services.caddy
        services.ipsec
        services.spire-agent-ssh
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
    inputs.nixpkgs.nixosModules.readOnlyPkgs
  ];
  nixosSpecialArgs = {
    inherit
      profiles
      homeProfiles
      ;
    flakeConfig = args.config;
  };
in
{
  options.easy-hosts.hosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }: {
          modules = self.lib.mkImports profiles.nixos.${name};
          deployable = lib.mkDefault true;
        }
      )
    );
  };
  config = {
    easy-hosts.path = ./non-existent;
    easy-hosts.useGlobalPkgs = true;
    easy-hosts.shared = {
      modules = nixosModules;
      specialArgs = nixosSpecialArgs;
    };

    easy-hosts.hosts = {
      router = { };
      hasee01 = { };
      hasee02 = { };
      hasee03 = { };
      hgh0 = { };
      desktop = { };
      laptop = { };
      sjc1 = { };
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
      lax0 = { };
      hkg0 = { };
      hkg1 = { };
    };
  };
}
