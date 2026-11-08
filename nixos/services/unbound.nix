{ pkgs, ... }:
let
  chinaZones = pkgs.runCommand "unbound-china.conf" { } ''
    cat ${pkgs.dnsmasq-china-list}/accelerated-domains.china.raw.txt \
        ${pkgs.dnsmasq-china-list}/apple.china.raw.txt \
      | LC_ALL=C sort -u \
      | sed -e 's|\(.*\)|forward-zone:\n  name: "\1."\n  forward-addr: 119.29.29.29\n  forward-addr: 223.5.5.5|' \
      > "$out"
  '';
in
{
  networking.vip = [
    "fdfe:3c59:ba97:1::1/128"
  ];
  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    enableRootTrustAnchor = false;
    checkconf = true;
    settings = {
      server = {
        interface = [ "fdfe:3c59:ba97:1::1" ];
        access-control = [
          "0.0.0.0/0 allow"
          "::/0 allow"
        ];
        module-config = "iterator";
        minimal-responses = true;
        tls-cert-bundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            "8.8.8.8@853#dns.google"
            "8.8.4.4@853#dns.google"
          ];
          forward-tls-upstream = true;
        }
      ];
      include = "\"${chinaZones}\"";
    };
  };
}
