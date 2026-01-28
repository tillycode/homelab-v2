{ lib, ... }:
{
  options.sops.agePublicKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "The age public key for the secret encryption.";
  };
}
