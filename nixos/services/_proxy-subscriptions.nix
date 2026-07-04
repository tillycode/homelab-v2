{ config, pkgs, ... }:
{
  systemd.services.proxy-subscriptions = {
    enableStrictShellChecks = true;
    script = ''
      mkdir -p /var/lib/proxy-subscriptions/subscription
      tar -xvf ${
        config.sops.secrets."proxy/subscriptions.tar.gz".path
      } -C /var/lib/proxy-subscriptions/subscription
    '';
    postStop = ''
      rm -rf /var/lib/proxy-subscriptions/*
    '';
    path = with pkgs; [
      gnutar
      gzip
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Group = "nginx";
      StateDirectory = "proxy-subscriptions";
    };
  };

  sops.genSecrets."proxy/subscriptions.tar.gz" = {
    script = [
      "${pkgs.devPackages.scripts.editable}/bin/proxy-keydrv"
      "gen-subscription"
    ];
    input = "proxy/settings.yaml";
  };
}
