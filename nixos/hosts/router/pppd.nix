{
  lib,
  pkgs,
  config,
  ...
}:
let
  wanIface = "wan";
  pppIface = "ppp0";
in
{
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  services.pppd = {
    enable = true;
    package = pkgs.ppp_2_5_5;
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
      # telecom advertise unusable IPv6 DNS servers
      UseDNS = false;
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
