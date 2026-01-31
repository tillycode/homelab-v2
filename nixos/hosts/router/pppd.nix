{
  lib,
  pkgs,
  config,
  ...
}:
let
  wanIface = "wan";
  pppIface = "ppp0";

  resolvectl = lib.getExe' pkgs.systemd "resolvectl";
  logger = lib.getExe' pkgs.util-linux "logger";
  ip-up-script = pkgs.writeShellScript "ppp-ip-up.sh" ''
    set -euo pipefail
    dns=()
    [[ -n ''${DNS1:-} ]] && dns+=("''$DNS1")
    [[ -n ''${DNS2:-} ]] && dns+=("''$DNS2")
    if [[ ''${#dns[@]} -gt 0 ]]; then
      ${resolvectl} dns ${pppIface} "''${dns[@]}"
      ${logger} -t pppd-dialer-ip-up "set DNS: ''${dns[*]}"
    else
      ${resolvectl} dns ${pppIface} ""
      ${logger} -t pppd-dialer-ip-up "cleared DNS"
    fi
  '';
  ip-down-script = pkgs.writeShellScript "ppp-ip-down.sh" ''
    set -euo pipefail
    resolvectl dns ${pppIface} ""
    ${logger} -t pppd-dialer-ip-down "cleared DNS"
  '';
in
{
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.pppd = {
    enable = true;
    peers.dialer = {
      autostart = true;
      config = ''
        plugin pppoe.so

        nic-${wanIface}
        ifname ${pppIface}

        mru 1492
        mtu 1492
        usepeerdns
        name ad87182800
        pap-secrets ${config.sops.secrets."ppp/pap-secrets".path}
        ip-up-script ${ip-up-script}
        ip-down-script ${ip-down-script}

        persist
        maxfail 0
        holdoff 5

        defaultroute
      '';
    };
  };
  systemd.services.pppd-dialer = {
    preStart = ''
      ${lib.getExe' pkgs.iproute2 "ip"} link set ${wanIface} up
    '';
    # nixpkgs defaults to Before=network.target, Wants=network.target, After=network-pre.target,
    # which is similar to systemd-networkd and systemd-resolved.
    # This causes ssh won't be available until this service reports ready or timeouts,
    # due to After=network.target in sshd.service.
    # However, according to https://github.com/systemd/systemd/blob/v258.2/docs/NETWORK_ONLINE.md,
    # I think setting to After=network.target is more appropriate.
    # This service is not a "network management stack".
    # It needs a "network management stack" setting up the WAN interface.
    # Ant it is a requirement of being online. This can be enforce by systemd-network-wait-online.
    before = lib.mkForce [ ];
    wants = lib.mkForce [ ];
    after = lib.mkForce [ "network.target" ];
  };

  systemd.network.networks."40-${pppIface}" = {
    matchConfig.Name = pppIface;
    DHCP = "ipv6";
    networkConfig = {
      KeepConfiguration = "static";
      IPv6AcceptRA = true;
    };
    dhcpV6Config = {
      PrefixDelegationHint = "::/60";
      UseDelegatedPrefix = true;
      WithoutRA = "solicit";
    };
  };

  systemd.network.wait-online.anyInterface = false;
  systemd.network.wait-online.extraArgs = [
    "-i"
    pppIface
  ];

  ## ---------------------------------------------------------------------------
  ## SECRETS
  ## ---------------------------------------------------------------------------
  sops.secrets."ppp/pap-secrets" = {
    restartUnits = [ "pppd-dialer.service" ];
  };

  systemd.network.config.networkConfig = {
    ManageForeignRoutes = false;
  };
}
