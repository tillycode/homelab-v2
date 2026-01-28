{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";

    # libraries

    systems.url = "path:systems.nix";
    systems.flake = false;

    blank.url = "path:blank";
    blank.flake = false;

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";
    deploy-rs.inputs.flake-compat.follows = "blank";

    # flake modules

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.flake-compat.follows = "blank";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.gitignore.follows = "blank";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    # nixos modules

    preservation.url = "github:nix-community/preservation";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager?ref=release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { flake-parts, ... }@inputs:
    let
      self-lib = import ./lib { inherit (inputs.nixpkgs) lib; };
      modules = self-lib.listModules ./flake-modules;
      profiles = self-lib.listModules ./flake;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
        inputs.git-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.home-manager.flakeModules.default
      ]
      ++ self-lib.mkImports modules
      ++ self-lib.mkImports profiles;

      flake.lib = self-lib;
      flake.flakeModules = self-lib.mkModules modules;

      systems = import inputs.systems;
    };
}
