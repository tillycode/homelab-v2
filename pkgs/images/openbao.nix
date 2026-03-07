{
  dockerTools,
  bash,
  openbao,
  coreutils,
  writeTextDir,
  tpm2-tss,
  tpm2-pkcs11,
  gnused,
}:
let
  fapiConfig = writeTextDir "etc/tpm2-tss/fapi-config.json" (
    builtins.toJSON {
      profile_name = "P_ECCP256SHA256";
      profile_dir = "${tpm2-tss}/etc/tpm2-tss/fapi-profiles/";
      user_dir = "~/.local/share/tpm2-tss/user/keystore/";
      system_dir = "/var/lib/tpm2-tss/system/keystore";
      tcti = "";
      system_pcrs = [ ];
      log_dir = "/var/log/tpm2-tss/eventlog/";
      firmware_log_file = "/dev/null";
      ima_log_file = "/dev/null";
      ek_cert_less = "no";
    }
  );
in
dockerTools.buildLayeredImage {
  name = "ghcr.io/tillycode/openbao";
  tag = openbao.version + "-3";
  contents = [
    bash
    coreutils
    openbao
    dockerTools.binSh
    dockerTools.caCertificates
    fapiConfig
    tpm2-pkcs11
    gnused
  ];
  extraCommands = ''
    mkdir -p openbao/{logs,file,config}
    mkdir -p usr/local/bin
    mkdir -m 775 -p var/log/tpm2-tss/eventlog
    mkdir -m 777 -p tmp
    echo -e "#!/bin/sh\nexec \"\''${@}\"" > usr/local/bin/docker-entrypoint.sh
    chmod +x usr/local/bin/docker-entrypoint.sh
  '';
  fakeRootCommands = ''
    chown :399 var/log/tpm2-tss/eventlog
  '';
  config = {
    Entrypoint = [ "/bin/bao" ];
  };
}
