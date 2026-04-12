{ self, lib, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      config,
      ...
    }:
    let
      scripts = pkgs.devPackages.scripts;

      nixosChecks = lib.concatMapAttrs (
        name: nixosConfig:
        lib.optionalAttrs (nixosConfig.config.nixpkgs.hostPlatform.system == system) {
          "nixos-${name}" = nixosConfig.config.system.build.toplevel;
        }
      ) self.nixosConfigurations;

      packageChecks = lib.mapAttrs' (
        name: drv: lib.nameValuePair "package-${builtins.replaceStrings [ "/" ] [ "-" ] name}" drv
      ) config.packages;

      devshellChecks = lib.mapAttrs' (
        name: drv: lib.nameValuePair "devshell-${name}" drv
      ) config.devShells;
    in
    {
      checks =
        nixosChecks
        // packageChecks
        // devshellChecks
        // {
          check-generated-host-secrets = scripts.checkGeneratedHostSecrets { flake = self; };
        };
    };
}
