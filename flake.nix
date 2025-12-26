{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";

    # libraries

    systems.url = "github:nix-systems/x86_64-linux";

    blank.url = "github:divnix/blank";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    # flake modules

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.flake-compat.follows = "blank";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.gitignore.follows = "blank";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
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
      ]
      ++ self-lib.mkImports modules
      ++ self-lib.mkImports profiles;

      flake.lib = self-lib;
      flake.flakeModules = self-lib.mkImported modules;

      systems = import inputs.systems;
    };
}
