{
  lib,
  config,
  ...
}:
let
  genSecretType = lib.types.submodule {
    options = {
      script = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "The script to be executed.";
      };
      input = lib.mkOption {
        type = lib.types.str;
        description = "The input path of the script.";
      };
    };
  };
in
{
  options.sops = {
    genSecrets = lib.mkOption {
      type = lib.types.attrsOf genSecretType;
      default = { };
      description = "The secrets to be generated.";
    };
  };
  config.sops.secrets = lib.mapAttrs (name: value: {
  }) config.sops.genSecrets;
}
