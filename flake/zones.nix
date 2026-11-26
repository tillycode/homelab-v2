{ inputs, ... }:
let
  inherit (inputs.dns.lib.combinators) a cname;
in
{
  zones."szp15.com" = {
    useOrigin = true;

    SOA = {
      nameServer = "ns1";
      adminEmail = "me@szp.io";
      serial = 2026112603;
    };
    NS = [ "ns1" ];
    A = [
      (a "47.96.145.133")
    ];
    AAAA = [
      (a "2408:4005:3c4:a40:d5b6:55ed:95b4:4eed")
    ];

    subdomains = {
      ns1.AAAA = [ (a "fdfe:3c59:ba97:1::2") ];
      openbao.AAAA = [ (a "fdfe:3c59:ba97:1::2") ];
      spire.AAAA = [ (a "fdfe:3c59:ba97:1::2") ];
      nodes.subdomains = {
        router.A = [ (a "10.112.8.1") ];
        hasee01.A = [ (a "10.112.8.2") ];
        hasee02.A = [ (a "10.112.8.3") ];
        hasee03.A = [ (a "10.112.8.4") ];
        desktop.A = [ (a "10.112.8.5") ];
        laptop.A = [ (a "10.112.8.11") ];
        hgh0.CNAME = [ (cname "hgh0.nodes.szp.io.") ];
        hkg0.CNAME = [ (cname "hkg0.nodes.szp.io.") ];
        hkg1.CNAME = [ (cname "hkg1.nodes.szp.io.") ];
        sjc1.CNAME = [ (cname "sjc1.nodes.szp.io.") ];
        lax0.CNAME = [ (cname "lax0.nodes.szp.io.") ];
      };
    };
  };
}
