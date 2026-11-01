{ pkgs, ... }:
let
  # Match neatdns: both the China and Apple lists use domestic resolvers.
  chinaZones = pkgs.runCommand "named-china.conf" { } ''
    cat ${pkgs.dnsmasq-china-list}/accelerated-domains.china.raw.txt \
        ${pkgs.dnsmasq-china-list}/apple.china.raw.txt \
      | LC_ALL=C sort -u \
      | awk 'NF { printf "zone \"%s\" { type forward; forward only; forwarders { 119.29.29.29; 223.5.5.5; }; };\n", $0 }' \
      > "$out"
  '';
in
{
  networking.vip = [
    "fdfe:3c59:ba97:1::1/128"
  ];
  services.bind = {
    enable = true;
    listenOn = [ ];
    listenOnIpv6 = [ "fdfe:3c59:ba97:1::1" ];
    forwarders = [
      "8.8.8.8"
      "8.8.4.4"
    ];
    cacheNetworks = [
      "0.0.0.0/0"
      "::/0"
    ];
    forward = "only";
    extraOptions = ''
      dnssec-validation no;
      minimal-responses yes;
      max-cache-ttl 3600;
      max-ncache-ttl 60;
    '';
    extraConfig = ''
      include "${chinaZones}";
    '';
  };
}
