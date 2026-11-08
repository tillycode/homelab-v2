{
  lib,
  config,
  self,
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
  zoneFile = ./szp15.com.zone;
in
{
  networking = {
    vip = [ "${anycastAddress}/128" ];
    firewall.allowedTCPPorts = [ 53 ];
    firewall.allowedUDPPorts = [ 53 ];
    resolvconf.useLocalResolver = false;
  };

  environment.etc."zones/szp15.com" = lib.mkIf isPrimary {
    source = zoneFile;
  };

  systemd.services.bind = lib.mkIf isPrimary {
    reloadTriggers = [ config.environment.etc."zones/szp15.com".source ];
    # The /etc symlink is only available at runtime, outside the build sandbox.
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
        file = if isPrimary then "/etc/zones/szp15.com" else "${cfg.directory}/szp15.com";
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
