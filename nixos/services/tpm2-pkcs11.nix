{ pkgs, ... }:
{
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    # esapi has fewer footprints on the filesystems
    pkcs11.package = pkgs.tpm2-pkcs11-esapi;
    tctiEnvironment.enable = true;
  };

  environment.systemPackages = with pkgs; [
    opensc
    tpm2-tools
  ];
  environment.variables.TPM2_PKCS11_STORE = "/var/lib/tpm2_pkcs11";
  environment.shellAliases.pkcs11-tool = "pkcs11-tool --module /run/current-system/sw/lib/libtpm2_pkcs11.so";

  # same as the K8s openbao runAsGroup
  users.groups.tss.gid = 399;

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/tpm2_pkcs11";
      mode = "2770";
      group = "tss";
    }
  ];
}
