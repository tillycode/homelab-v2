{
  importPath ? throw "importPath is missing",
  flake ? builtins.getFlake importPath,
  eval ? false,
}:
let
  output = {
    hosts = builtins.mapAttrs (name: value: {
      publicKey = value.config.sops.agePublicKey;
      secrets = map (x: x.key) (builtins.attrValues value.config.sops.secrets);
      genSecrets = builtins.mapAttrs (_: value: {
        inherit (value)
          script
          input
          ;
      }) value.config.sops.genSecrets;
    }) (flake.outputs.nixosConfigurations or { });
  };
  pkgs = flake.legacyPackages.${builtins.currentSystem};
in
if eval then output else pkgs.writeText "evaluation.json" (builtins.toJSON output)
