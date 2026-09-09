{
  lib,
  pkgs,
  ...
}:
let
  excluded = [
    # private
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "fc00::/7"
    # loopback
    "127.0.0.0/8"
    "::1/128"
    # multicast
    "224.0.0.0/4"
    "ff00::/8"
    # link-local unicast
    "169.254.0.0/16"
    "fe80::/10"
    # interface local multicast
    "ff01::/16"
    # CGNAT
    "100.64.0.0/10"
    # unspecified
    "0.0.0.0/8"
    "::/128"
    # server addresses
    "87.83.107.0/24"
    "194.104.147.128/26"
    "185.218.4.0/22"
    "209.209.59.0/24"
    "47.96.0.0/15"
  ];
  mark = "0x01000000";
  table = 2023;
  priority = 10000;

  excluded4 = lib.filter (address: !lib.hasInfix ":" address) excluded;
  excluded6 = lib.filter (lib.hasInfix ":") excluded;

  sing-box-post-start = pkgs.writeShellApplication {
    name = "sing-box-post-start";
    runtimeInputs = with pkgs; [
      iproute2
      util-linux
      procps
      nftables
      bash
    ];
    text = ''
      ready=false
      for _ in {1..30}; do
        if [[ -e /run/sing-box/netns.pid ]]; then
          ready=true
          break
        fi
        sleep 1
      done
      if [[ $ready = false ]]; then
        echo "sing-box netns did not start in time"
        exit 1
      fi
      pid=$(</run/sing-box/netns.pid)
      ip link add sing-box address ee:ee:ee:ee:ee:ee type veth peer name eth0 netns "$pid"
      nsenter -t "$pid" -U -n --preserve-credentials --keep-caps --no-fork -- bash <<EOF
      set -e
      ip link set lo up
      ip neighbor add 169.254.1.1 lladdr ee:ee:ee:ee:ee:ee dev eth0
      ip address add 169.254.20.2/32 dev eth0
      ip -6 address add fdfe:dcba:9877::2/126 dev eth0 nodad
      ip link set eth0 up
      ip route add 169.254.1.1 dev eth0 scope link
      ip route add default via 169.254.1.1 dev eth0 src 169.254.20.2
      ip -6 route add default via fdfe:dcba:9877::1
      sysctl -qw net.ipv6.conf.all.forwarding=1
      EOF

      nft add table inet sing-box-routing
    '';
  };
  sing-box-post-stop = pkgs.writeShellApplication {
    name = "sing-box-post-stop";
    runtimeInputs = with pkgs; [
      nftables
      iproute2
    ];
    text = ''
      nft add table inet sing-box-routing '{ flags dormant; }'
      ip link delete sing-box || true
    '';
  };

  sing-box-reactivate = pkgs.writeShellApplication {
    name = "sing-box-reactivate";
    runtimeInputs = with pkgs; [
      nftables
      systemd
    ];
    text = ''
      if systemctl is-active --quiet sing-box.service; then
        nft add table inet sing-box-routing
      fi
    '';
  };
in
{
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = lib.mkDefault 1;
    "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
  };

  networking.nftables = {
    tables.sing-box-routing = {
      family = "inet";
      content = ''
        flags dormant;
        set excluded4 {
          type ipv4_addr; flags interval; auto-merge;
          elements = { ${lib.concatStringsSep ", " excluded4} }
        }
        set excluded6 {
          type ipv6_addr; flags interval; auto-merge;
          elements = { ${lib.concatStringsSep ", " excluded6} }
        }
        chain classify {
          meta mark != 0 return
          ct mark != 0 return
          ct direction reply return
          meta l4proto != { tcp, udp, icmp, ipv6-icmp } return
          fib daddr type { local, broadcast } return
          ip daddr @excluded4 return
          ip6 daddr @excluded6 return
          counter meta mark set ${mark}
        }
        chain output {
          type route hook output priority mangle + 5; policy accept;
          meta skuid { "sing-box", "systemd-resolve" } return
          jump classify
        }
        chain prerouting {
          type filter hook prerouting priority dstnat - 10; policy accept;
          iifname "sing-box" return
          jump classify
        }
      '';
    };
    # ensure no DNS loops
    tables.sing-box-dns-guard = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority filter; policy accept;
          meta skuid "sing-box" ip daddr { 127.0.0.53, 127.0.0.54, 169.254.20.2 } meta l4proto { tcp, udp } th dport 53 counter reject
        }
      '';
    };
    preCheckRuleset = ''
      sed -i 's/"sing-box"/"root"/g; s/"systemd-resolve"/"root"/g' ruleset.conf
    '';
  };

  systemd.network.networks."40-sing-box" = {
    name = "sing-box";
    address = [
      "169.254.1.1/32"
      "fdfe:dcba:9877::1/126"
    ];
    linkConfig.RequiredForOnline = "no";
    networkConfig = {
      DNS = "172.19.0.2";
      Domains = "~.";
      DNSDefaultRoute = false;
      DNSSEC = false;
      IPv6AcceptRA = false;
      IPv4AcceptLocal = true;
    };
    routes = [
      {
        Gateway = "169.254.20.2";
        Table = table;
      }
      {
        Gateway = "fdfe:dcba:9877::2";
        Table = table;
      }
      {
        Destination = "169.254.20.2";
      }
      {
        Destination = "fdfe:dcba:9877::2";
      }
      {
        Destination = "172.19.0.2/32";
        Gateway = "169.254.20.2";
      }
    ];
    routingPolicyRules = [
      {
        Family = "both";
        FirewallMark = mark;
        Table = table;
        Priority = priority;
      }
    ];
  };

  systemd.services.sing-box = {
    after = [
      "nftables.service"
      "systemd-resolved.service"
    ];
    serviceConfig = {
      ExecStartPost = [ "+${lib.getExe sing-box-post-start}" ];
      ExecStopPost = [ "+${lib.getExe sing-box-post-stop}" ];
    };
  };
  systemd.services.nftables = {
    serviceConfig = {
      ExecStartPost = [ "+${lib.getExe sing-box-reactivate}" ];
      ExecReload = [ "+${lib.getExe sing-box-reactivate}" ];
    };
  };

  networking.firewall.extraForwardRules = ''
    oifname "sing-box" accept
    iifname "sing-box" accept
  '';
  networking.firewall.extraReversePathFilterRules = ''
    iifname "sing-box" accept
  '';
}
