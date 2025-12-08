{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";

    # libs

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    # devshell

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
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
        ]
        ++ selfLib.mkImports modules;

        systems = [
          "aarch64-linux"
          "x86_64-linux"
        ];
        flake.lib = selfLib;
      }
    );
}
