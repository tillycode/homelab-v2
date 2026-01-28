{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      scripts = pkgs.devPackages.scripts;
    in
    {
      checks = {
        check-generated-host-secrets = scripts.checkGeneratedHostSecrets { flake = self; };
      };
    };
}
