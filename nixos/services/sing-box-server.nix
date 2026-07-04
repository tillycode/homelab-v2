{ pkgs, config, ... }:
{
  imports = [
    ./_proxy-upstream.nix
  ];

  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.sing-box = {
    enable = true;
    settings = {
      log.level = "trace";
      # inbounds are added via sops
      outbounds = [
        {
          tag = "direct";
          type = "direct";
        }
      ];
      route = {
        final = "direct";
        rules = [
          {
            ip_is_private = true;
            action = "reject";
            method = "drop";
          }
        ];
      };
    };
  };
  systemd.services.sing-box = {
    preStart = ''
      ln -sf "$CREDENTIALS_DIRECTORY/inbounds.json" /run/sing-box/zinbounds.json
    '';
    serviceConfig = {
      LoadCredential = "inbounds.json:${config.sops.secrets."sing-box/inbounds.json".path}";
    };
  };

  ## ---------------------------------------------------------------------------
  ## SECRETS
  ## ---------------------------------------------------------------------------
  sops.genSecrets."sing-box/inbounds.json" = {
    script = [
      "${pkgs.devPackages.scripts.editable}/bin/proxy-keydrv"
      "gen-server"
      "--name"
      config.system.name
    ];
    input = "proxy/settings.yaml";
  };
  sops.secrets."sing-box/inbounds.json" = {
    restartUnits = [ "sing-box.service" ];
  };
}
