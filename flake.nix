{
  description = "A very basic flake";

  inputs = {
    nixpkgs.follows = "clan-core/nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # libraries

    systems.url = "path:systems.nix";
    systems.flake = false;

    blank.url = "path:blank";
    blank.flake = false;

    flake-parts.follows = "clan-core/flake-parts";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    dns.url = "github:kirelagin/dns.nix";
    dns.inputs.nixpkgs.follows = "nixpkgs";
    dns.inputs.flake-utils.follows = "flake-utils";

    import-tree.url = "github:denful/import-tree";

    # flake modules

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.flake-compat.follows = "blank";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    # nixos modules

    preservation.url = "github:nix-community/preservation";

    disko.follows = "clan-core/disko";

    home-manager.url = "github:nix-community/home-manager?ref=release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.follows = "clan-core/sops-nix";

    niks3.url = "github:Mic92/niks3";
    niks3.inputs.nixpkgs.follows = "nixpkgs";
    niks3.inputs.treefmt-nix.follows = "blank";

    # frameworks
    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/26.05.tar.gz";
    clan-core.inputs.systems.follows = "systems";
    clan-core.inputs.treefmt-nix.follows = "blank";
  };

  outputs =
    { flake-parts, import-tree, ... }@inputs:
    let
      self-lib = import ./lib { inherit (inputs.nixpkgs) lib; };
      modules = self-lib.listModules ./flake-modules;
      profiles = self-lib.listModules ./flake;
    in
    # TODO: refactoring to
    #   flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules)
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
        inputs.git-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.home-manager.flakeModules.default
        (import-tree ./modules)
      ]
      ++ self-lib.mkImports modules
      ++ self-lib.mkImports profiles;

      flake.lib = self-lib;
      flake.flakeModules = self-lib.mkModules modules;

      systems = import inputs.systems;
    };
}
