{ pkgs, config, ... }:
{
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;

    # FIXME: tpm2-tss doesn't support on-dir CA which is used by Intel 11th gen CPUs.
    #   See https://github.com/tpm2-software/tpm2-tss/issues/2934.
    #   A fix has been merged into tpm2-tss, but not yet released.
    fapi.ekCertLess = true;
  };

  environment.systemPackages = with pkgs; [
    opensc
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
    {
      directory = config.security.tpm2.fapi.systemDir;
      mode = "2770";
      group = "tss";
    }
  ];
}
