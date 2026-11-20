{
  pkgs,
  config,
  lib,
  ...
}:
let
  domain = "${config.system.name}.eh578599.xyz";
  port = config.ports.xray-upstream;
in
{
  services.caddy = {
    httpsPort = port;
    globalConfig = ''
      default_bind ::1
      auto_https disable_redirects
      cert_issuer acme {
        disable_tlsalpn_challenge
      }
      servers {
        protocols h1 h2
      }
    '';
    virtualHosts = {
      "http://".extraConfig = ''
        bind ""
        redir https://{host}{uri} permanent
      '';
      ${domain}.extraConfig = "respond 404";
    };
  };

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
          user = "me";
          outboundTag = "direct";
        }
        {
          ip = [ "geoip:private" ];
          outboundTag = "blocked";
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
      "--port"
      (toString port)
    ];
    input = "proxy/settings.yaml";
  };
  sops.secrets."xray/inbounds.json" = {
    reloadUnits = [ "xray.service" ];
  };
}
