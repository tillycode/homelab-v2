{
  lib,
  config,
  self,
  pkgs,
  flakeConfig,
  ...
}:
let
  primary = [ "router" ];
  inherit (config.system) name;
  cfg = config.services.bind;
  isPrimary = lib.elem name primary;
  nodes = lib.filterAttrs (_: node: node.config.services.bind.enable) self.nixosConfigurations;
  addresses = nodes: lib.mapAttrsToList (_: node: node.config.networking.ipv6Address) nodes;
  primaryAddresses = addresses (
    lib.filterAttrs (_: node: lib.elem node.config.system.name primary) nodes
  );
  peerAddresses = addresses (lib.filterAttrs (_: node: node.config.system.name != name) nodes);
  anycastAddress = "fdfe:3c59:ba97:1::2";
  zoneFile = pkgs.writeText "szp15.com.zone" (toString flakeConfig.zones."szp15.com");
  zonePath = "${cfg.directory}/szp15.com";
in
{
  networking = {
    vip = [ "${anycastAddress}/128" ];
    firewall.allowedTCPPorts = [ 53 ];
    firewall.allowedUDPPorts = [ 53 ];
    resolvconf.useLocalResolver = false;
  };

  systemd.tmpfiles.settings.bind = lib.mkIf isPrimary {
    "${zonePath}"."f+" = {
      user = "named";
      group = "named";
      argument = "$INCLUDE ${zoneFile}\n";
    };
  };

  systemd.services.bind = lib.mkIf isPrimary {
    reloadTriggers = [ zoneFile ];
    preStart = lib.mkAfter ''
      ${lib.getExe' cfg.package "named-checkconf"} -z ${cfg.configFile}
    '';
  };

  services.bind = {
    enable = true;
    checkConfig = !isPrimary;
    directory = "/var/lib/bind";
    listenOn = [ ];
    listenOnIpv6 = [
      anycastAddress
      config.networking.ipv6Address
    ];
    forwarders = [ ];
    extraOptions = ''
      recursion no;
      notify-source-v6 ${config.networking.ipv6Address};
      transfer-source-v6 ${config.networking.ipv6Address};
    '';
    zones = {
      "szp15.com" = {
        master = isPrimary;
        file = zonePath;
        masters = lib.mkIf (!isPrimary) primaryAddresses;
        slaves = lib.mkIf isPrimary peerAddresses;
        extraConfig =
          if isPrimary then
            ''
              notify explicit;
              also-notify { ${lib.concatMapStrings (address: "${address}; ") peerAddresses} };
            ''
          else
            ''
              notify no;
              allow-transfer { none; };
            '';
      };
    };
  };
}
