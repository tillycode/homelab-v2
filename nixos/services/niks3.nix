{ config, ... }:
{
  services.niks3 = {
    enable = true;
    httpAddr = "127.0.0.1:${toString config.ports.niks3}";
    database.createLocally = true;

    s3 = {
      endpoint = "b0f346a20f67aebba04ace0a91cf49c0.r2.cloudflarestorage.com";
      bucket = "cache";
      accessKeyFile = config.sops.secrets."niks3/s3-access-key".path;
      secretKeyFile = config.sops.secrets."niks3/s3-secret-key".path;
    };
    apiTokenFile = config.sops.secrets."niks3/api-token".path;
    signKeyFiles = [ config.sops.secrets."niks3/sign-key".path ];

    cacheUrl = "https://cache.szp.io";
    nginx = {
      enable = true;
      domain = "niks3.szp.io";
    };

    oidc.providers.github = {
      issuer = "https://token.actions.githubusercontent.com";
      audience = "https://niks3.szp.io";
      boundClaims.repository_owner = [ "tillycode" ];
    };

    oidc.providers.vault = {
      issuer = "https://vault.szp15.com/v1/identity/oidc";
      audience = "https://niks3.szp.io";
    };
  };

  sops.secrets."niks3/s3-access-key" = {
    owner = "niks3";
    group = "niks3";
  };
  sops.secrets."niks3/s3-secret-key" = {
    owner = "niks3";
    group = "niks3";
  };
  sops.secrets."niks3/api-token" = {
    owner = "niks3";
    group = "niks3";
  };
  sops.secrets."niks3/sign-key" = {
    owner = "niks3";
    group = "niks3";
  };
}
