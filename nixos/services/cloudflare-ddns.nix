{ config, ... }:
let
  inherit (config.system) name;
  iface =
    {
      router = "ppp0";
    }
    .${name};
in
{
  services.cloudflare-ddns = {
    enable = true;
    domains = [ "${name}.nodes.szp.io" ];
    credentialsFile = config.sops.templates."cloudflare-ddns.env".path;
    provider.ipv4 = "local.iface:${iface}";
    provider.ipv6 = "local.iface:${iface}";
  };
  systemd.services.cloudflare-ddns = {
    environment.DELETE_ON_FAILURE = "false";
    serviceConfig.RestrictAddressFamilies = [ "AF_NETLINK" ];
  };

  sops.templates."cloudflare-ddns.env".content = ''
    CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare-ddns/${name}"}
  '';
  sops.secrets."cloudflare-ddns/${name}" = {
    restartUnits = [ "cloudflare-ddns.service" ];
  };
}
