{
  config,
  lib,
  pkgs,
  ...
}:
let
  address = "fdfe:3c59:ba97:1::4";
  certDirectory = config.security.acme.certs."spire.szp15.com".directory;
in
{
  imports = [
    ./_spire-controller-manager.nix
    ./_spire-entries.nix
  ];

  networking.vip = [ "${address}/128" ];

  services.spire.server = {
    enable = true;
    settings = {
      server = {
        trust_domain = "szp15.com";
        bind_address = address;
        federation.bundle_endpoint = {
          address = address;
          port = 443;
          profile.https_web.serving_cert_file = {
            cert_file_path = "${certDirectory}/fullchain.pem";
            key_file_path = "${certDirectory}/key.pem";
            file_sync_interval = "1h";
          };
        };
        experimental = {
          agent_spiffe_id_as_selector = true;
        };
      };
      plugins = {
        # To provision
        #
        #   bao secrets enable -path=spire-transit transit
        #   bao policy write spire-keymanager - <<EOF
        #   path "spire-transit/keys/*" {
        #     capabilities = ["create", "read", "update", "delete", "list"]
        #   }
        #
        #   path "spire-transit/sign/*" {
        #     capabilities = ["update"]
        #   }
        #   EOF
        #   bao write identity/entity name=spire-server policies=spire-keymanager
        #
        #   bao auth enable approle
        #   bao write -f auth/approle/role/spire-server
        #   bao write identity/entity-alias \
        #     name="$(bao read -field=role_id auth/approle/role/spire-server/role-id)" \
        #     canonical_id="$(bao read -field=id identity/entity/name/spire-server)" \
        #     mount_accessor="$(bao auth list -format=json | jq -r '.["approle/"].accessor')"
        #   bao read auth/approle/role/spire-server/role-id
        #   bao write -f auth/approle/role/spire-server/secret-id
        KeyManager.hashicorp_vault.plugin_data = {
          vault_addr = "https://openbao.szp15.com";
          key_identifier_file = "$STATE_DIRECTORY/key_identifier";
          transit_engine_path = "spire-transit";
          approle_auth = { };
        };
        DataStore.sql.plugin_data = {
          database_type = "sqlite3";
          connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
        };
        NodeAttestor.tpm = {
          plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server";
          plugin_data = {
            hash_path = toString (
              pkgs.runCommandLocal "tpm2-hashes" {
                # Use the following command to get hash
                #
                #    nix shell nixpkgs#spire-tpm-plugin --command sudo get_tpm_pubhash
                hashes = lib.attrValues (import ./_spire-tpm-pub-hashes.nix);
                __structuredAttrs = true;
              } ''mkdir -p $out && touch "''${hashes[@]/#/$out/}"''
            );
          };
        };
        NodeAttestor.sshpop.plugin_data = {
          cert_authorities = [
            config.programs.ssh.knownHosts.szp15-com.publicKey
          ];
          canonical_domain = "nodes.szp15.com";
          agent_path_template = "/{{ .PluginName }}/static/{{ .Hostname }}";
        };
      };
    };
  };

  users.users.spire-server = {
    isSystemUser = true;
    group = "spire-server";
  };
  users.groups.spire-server = { };

  systemd.services.spire-server = {
    serviceConfig = {
      RestartSec = "5s";
      DynamicUser = lib.mkForce false;
      EnvironmentFile = config.sops.templates."spire.env".path;
      User = "spire-server";
      Group = "spire-server";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
    };
  };

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/spire/server";
      user = "spire-server";
      group = "spire-server";
      mode = "0700";
    }
  ];

  # To setup ACME
  #
  #   bao write pki/roles/spire-https allowed_domains=spire.szp15.com allow_bare_domains=true max_ttl=768h key_type=ec
  #   bao write -f pki/roles/spire-https/acme/new-eab
  security.acme.certs."spire.szp15.com" = {
    server = "https://openbao.szp15.com/v1/pki/roles/spire-https/acme/directory";
    listenHTTP = "[${address}]:80";
    environmentFile = config.sops.templates."spire-acme.env".path;
    group = "spire-server";
  };

  sops.secrets."spire-server/acme-eab-key" = { };
  sops.templates."spire-acme.env".content = ''
    LEGO_EAB=true
    LEGO_EAB_KID=2fa2f3fd-a4d2-f5e0-e3a0-bf4e3574dded
    LEGO_EAB_HMAC=${config.sops.placeholder."spire-server/acme-eab-key"}
  '';
  sops.secrets."spire-server/approle/role-id" = { };
  sops.secrets."spire-server/approle/secret-id" = { };
  sops.templates."spire.env".content = ''
    VAULT_APPROLE_ID=${config.sops.placeholder."spire-server/approle/role-id"}
    VAULT_APPROLE_SECRET_ID=${config.sops.placeholder."spire-server/approle/secret-id"}
  '';
}
