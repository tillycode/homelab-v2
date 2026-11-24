{
  config,
  lib,
  pkgs,
  inputs,
  utils,
  ...
}:
let
  address = "fdfe:3c59:ba97:1::3";
  certDirectory = config.security.acme.certs."openbao.szp15.com".directory;
  unstable = inputs.nixpkgs-unstable;
  cfg = config.services.openbao;
  secretsReplacement = utils.genJqSecretsReplacement {
    loadCredential = true;
  } cfg.settings "/run/openbao/openbao.hcl.json";
in
{
  disabledModules = [ "services/security/openbao.nix" ];
  imports = [
    (unstable + "/nixos/modules/services/security/openbao.nix")
  ];
  # Provision the TPM2 PKCS#11 module and tools
  #
  #   tpm2 clear
  #   pkcs11-tool --slot-index=0 --init-token --label=OpenBao
  #   pkcs11-tool --slot-index=0 --init-pin --login
  #   pkcs11-tool --slot-index=0 --keypairgen --login --label bao-unseal-01 --key-type RSA:2048
  #
  #   BAO_ADDR=https://openbao.szp15.com bao operator init -recovery-shares=1 -recovery-threshold=1
  services.openbao = {
    enable = true;
    plugins = with pkgs.openbaoPlugins; [
      kms-pkcs11
    ];
    settings = {
      ui = true;
      api_addr = "https://openbao.szp15.com";
      cluster_addr = "https://[${config.networking.ipv6Address}]:${toString config.ports.openbao-cluster}";
      listener.tcp = {
        type = "tcp";
        address = "[${address}]:443";
        cluster_address = "[${config.networking.ipv6Address}]:${toString config.ports.openbao-cluster}";
        tls_cert_file = "${certDirectory}/fullchain.pem";
        tls_key_file = "${certDirectory}/key.pem";
      };
      storage.raft = {
        path = "/var/lib/openbao";
        node_id = config.system.name;
      };
      seal.pkcs11 = {
        lib = "${pkgs.tpm2-pkcs11}/lib/libtpm2_pkcs11.so";
        mechanism = "CKM_RSA_PKCS_OAEP";
        token_label = "OpenBao";
        key_label = "bao-unseal-01";
        pin._secret = config.sops.secrets."openbao/hsm-pin".path;
      };
    };
  };

  networking.vip = [ "${address}/128" ];

  users.users.openbao = {
    isSystemUser = true;
    group = "openbao";
  };
  users.groups.openbao = { };
  systemd.services.openbao = {
    restartIfChanged = lib.mkForce true;
    preStart = secretsReplacement.script;
    environment.TPM2_PKCS11_STORE = config.environment.variables.TPM2_PKCS11_STORE;
    serviceConfig = {
      ExecStart = lib.mkForce (
        lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "server"
            "-config"
            "/run/openbao/openbao.hcl.json"
          ]
          ++ cfg.extraArgs
        )
      );
      DynamicUser = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      RestartSec = "5s";
      CapabilityBoundingSet = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      LoadCredential = secretsReplacement.credentials;
      SupplementaryGroups = [ "tss" ];
    };
  };

  security.acme.certs."openbao.szp15.com" = {
    dnsProvider = "cloudflare";
    dnsResolver = "223.5.5.5:53";
    credentialFiles = {
      "CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets."openbao/cloudflare-dns-api-token".path;
    };
    group = "openbao";
  };

  sops.secrets."openbao/cloudflare-dns-api-token" = { };
  sops.secrets."openbao/hsm-pin" = { };

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/openbao";
      user = "openbao";
      group = "openbao";
      mode = "0700";
    }
  ];
}
