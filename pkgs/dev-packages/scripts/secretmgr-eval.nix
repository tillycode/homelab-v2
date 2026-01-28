{
  importPath ? throw "importPath is missing",
  flake ? builtins.getFlake importPath,
}:
builtins.mapAttrs (name: value: {
  publicKey = value.config.sops.agePublicKey;
  secrets = map (x: x.key) (builtins.attrValues value.config.sops.secrets);
}) (flake.outputs.nixosConfigurations or { })
