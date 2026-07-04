{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./_proxy-upstream.nix
  ];
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.xray = {
    enable = true;
    settings = {
      log.logLevel = "warning";
      inbounds = [

      ];
      # inbounds are added via sops
      outbounds = [
        {
          protocol = "freedom";
          tag = "direct";
        }
        {
          protocol = "blackhole";
          tag = "blocked";
        }
      ];
      routing.rules = [
        {
          ip = [ "geoip:private" ];
          outboundTag = "direct";
        }
      ];

    };
  };
  systemd.services.xray = {
    script = lib.mkForce ''
      exec "${config.services.xray.package}/bin/xray" -confdir "$CREDENTIALS_DIRECTORY"
    '';
    serviceConfig = {
      LoadCredential = [
        "zinbounds.json:${config.sops.secrets."xray/inbounds.json".path}"
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # SECRETS
  # ---------------------------------------------------------------------------
  sops.genSecrets."xray/inbounds.json" = {
    script = [
      "${pkgs.devPackages.scripts.editable}/bin/proxy-keydrv"
      "gen-server"
      "--format"
      "xray"
      "--name"
      config.system.name
    ];
    input = "proxy/settings.yaml";
  };
  sops.secrets."xray/inbounds.json" = {
    reloadUnits = [ "xray.service" ];
  };
}
