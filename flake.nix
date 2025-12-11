{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";

    # libraries

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    blank.url = "github:divnix/blank";

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
    flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      let
        selfLib = import ./lib { inherit inputs lib; };
        modules = selfLib.listModules ./flake;
      in
      {
        imports = [
          inputs.devshell.flakeModule
          inputs.git-hooks.flakeModule
          inputs.treefmt-nix.flakeModule
        ]
        ++ selfLib.mkImports modules;

        systems = [
          "x86_64-linux"
        ];
        flake.lib = selfLib;
      }
    );
}
