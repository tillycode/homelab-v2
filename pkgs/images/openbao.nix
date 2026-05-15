{
  dockerTools,
  openbao,
  busybox,
  writeTextDir,
  writeTextFile,
  tpm2-pkcs11-esapi,
  vault-plugin-secrets-github,
  supercronic,
  logrotate,
}:
dockerTools.buildLayeredImage {
  name = "ghcr.io/tillycode/openbao";
  tag = openbao.version + "-4";
  contents = [
    busybox
    openbao
    dockerTools.binSh
    dockerTools.caCertificates
    tpm2-pkcs11-esapi
    supercronic
    logrotate
    vault-plugin-secrets-github
    (writeTextDir "etc/crontab" ''
      * * * * * /sbin/logrotate -s /tmp/logrotate.status /etc/logrotate.conf
    '')
    (writeTextDir "etc/logrotate.conf" ''
      /openbao/logs/audit.log {
          size 100k
          rotate 5
          compress
          missingok
          postrotate
              /bin/pkill -HUP -x bao
          endscript
      }
    '')
    (writeTextFile {
      name = "docker-entrypoint.sh";
      destination = "/usr/local/bin/docker-entrypoint.sh";
      executable = true;
      text = ''
        #!/bin/sh
        set -eu

        supercronic --quiet /etc/crontab &
        exec "$@"
      '';
    })
  ];
  extraCommands = ''
    mkdir -p openbao/{logs,file,config}
    mkdir -m 777 -p tmp
  '';
  config = {
    Entrypoint = [ "/bin/bao" ];
  };
}
