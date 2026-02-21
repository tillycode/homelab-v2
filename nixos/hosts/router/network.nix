{ pkgs, ... }:
{
  ## ---------------------------------------------------------------------------
  ## BONDING AND VLAN
  ## ---------------------------------------------------------------------------
  systemd.network.links = {
    "40-eth0" = {
      matchConfig.Path = "pci-0000:02:00.0";
      linkConfig.Name = "eth0";
    };
    "40-eth1" = {
      matchConfig.Path = "pci-0000:03:00.0";
      linkConfig.Name = "eth1";
    };
    "40-wlan0" = {
      matchConfig.Path = "pci-0000:04:00.0";
      linkConfig.Name = "wlan0";
    };
  };
  networking.bonds.bond0 = {
    interfaces = [
      "eth0"
      "eth1"
    ];
    driverOptions = {
      mode = "802.3ad";
      lacp_rate = "fast";
      xmit_hash_policy = "layer3+4";
      miimon = "100";
    };
  };

  networking.vlans = {
    wan = {
      id = 2;
      interface = "bond0";
    };
    lan = {
      id = 3;
      interface = "bond0";
    };
    svc = {
      id = 4;
      interface = "bond0";
    };
  };

  systemd.network.networks."40-eth0" = {
    linkConfig.MTUBytes = 9000;
  };
  systemd.network.networks."40-eth1" = {
    linkConfig.MTUBytes = 9000;
  };
  systemd.network.networks."40-wlan0" = {
    matchConfig.Name = "wlan0";
    linkConfig.Unmanaged = true;
  };
  systemd.network.networks."40-bond0" = {
    matchConfig.Name = "bond0";
    linkConfig.MTUBytes = 9000;
    networkConfig.IPv6AcceptRA = false;
  };

  ## ---------------------------------------------------------------------------
  ## WAN
  ## ---------------------------------------------------------------------------
  systemd.network.networks."40-wan" = {
    matchConfig.Name = "wan";
    linkConfig = {
      # ZTE ONU magic MAC address
      MACAddress = "00:07:29:55:35:57";
      MTUBytes = 1500;
    };
    address = [ "192.168.1.2/24" ];
    networkConfig = {
      IPv6AcceptRA = false;
    };
  };
  environment.systemPackages = with pkgs; [
    zteonu
    inetutils
  ];

  ## ---------------------------------------------------------------------------
  ## LAN
  ## ---------------------------------------------------------------------------
  systemd.network.networks."40-lan" = {
    matchConfig.Name = "lan";
    address = [ "192.168.23.1/24" ];
    linkConfig.MTUBytes = 1500;
    networkConfig = {
      # IPv4
      DHCPServer = true;
      # IPv6
      IPv6AcceptRA = false;
      DHCPPrefixDelegation = true;
      IPv6SendRA = true;
    };
    dhcpPrefixDelegationConfig = {
      UplinkInterface = ":auto";
      Announce = true;
      Assign = true;
      Token = "static:::1";
      SubnetId = "auto";
    };
    dhcpServerConfig = {
      ServerAddress = "192.168.23.1/24";
      DNS = [ "10.112.8.1" ];
      EmitRouter = true;
      PoolOffset = 100;
      PoolSize = 100;
    };
    dhcpServerStaticLeases = [
      {
        # AP
        MACAddress = "a4:a9:30:21:28:19";
        Address = "192.168.23.2";
      }
      {
        # printer
        MACAddress = "90:31:4b:98:9b:5b";
        Address = "192.168.23.4";
      }
    ];
  };
  services.resolved.extraConfig = ''
    DNSStubListenerExtra=10.112.8.1
  '';
  networking.firewall.interfaces.lan.allowedUDPPorts = [ 53 ];
  networking.firewall.interfaces.lan.allowedTCPPorts = [ 53 ];
  networking.firewall.interfaces.svc.allowedUDPPorts = [ 53 ];
  networking.firewall.interfaces.svc.allowedTCPPorts = [ 53 ];

  ## ---------------------------------------------------------------------------
  ## SVC
  ## ---------------------------------------------------------------------------
  systemd.network.networks."40-svc" = {
    matchConfig.Name = "svc";
    linkConfig.MTUBytes = 9000;
    address = [
      "10.112.8.1/24"
    ];
    networkConfig.IPv6AcceptRA = false;
  };

  ## ---------------------------------------------------------------------------
  ## NAT AND FIREWALL
  ## ---------------------------------------------------------------------------

  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.default.forwarding" = 1;
  };
  networking.nat = {
    enable = true;
    externalInterface = "ppp0";
    internalInterfaces = [
      "lan"
      "svc"
    ];
  };

  networking.firewall.filterForward = true;
  # allow DHCP traffic from lan
  networking.firewall.extraInputRules = ''
    meta nfproto ipv4 iifname lan udp sport 68 udp dport 67 accept comment "DHCPv4 client"
  '';
  # allow loadbalancer traffic from lan and wireguard
  networking.firewall.extraForwardRules = ''
    iifname {"lan", "wg0"} oifname "svc" ip daddr 10.112.10.0/24 accept
  '';

  networking.nftables.tables.mss-clamping = {
    family = "inet";
    content = ''
      	chain clamp-mss {
      		type filter hook forward priority mangle; policy accept;
      		tcp flags & (syn | rst) == syn tcp option maxseg size set rt mtu
      	}
    '';
  };
  networking.nftables.tables.nixos-fw = {
    family = "inet";
    content = ''
      chain drop-fragmented-packets {
        type filter hook prerouting priority -450;
        ip frag-off & 0x1fff != 0 jump {
          limit rate 1/second log prefix "fragmented packet: " level info
          counter drop
        }
      }
    '';
  };
}
