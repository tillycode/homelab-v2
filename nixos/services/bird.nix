{ config, lib, ... }:
let
  cfg = config.profiles.bird;
  inherit (cfg) advertiseIPv4DefaultRoute;
  learn = lib.optionalString advertiseIPv4DefaultRoute "\n  learn;";
  ipv4Import = if advertiseIPv4DefaultRoute then "where net = 0.0.0.0/0" else "none";
  babelSources = "RTS_BABEL, RTS_DEVICE";
  wiredSources = babelSources + lib.optionalString advertiseIPv4DefaultRoute ", RTS_INHERIT";

  babelProtocol = sources: interfaces: ''
    protocol babel {
      randomize router id;
      ipv4 {
        import all;
        export where source ~ [ ${sources} ];
      };
      ipv6 sadr {
        import all;
        export where source ~ [ ${sources} ];
      };
      ${lib.replaceStrings [ "\n" ] [ "\n  " ] (lib.removeSuffix "\n" interfaces)}
    }
  '';

  wiredInterfaces = lib.concatMapStrings (interface: ''
    interface ${builtins.toJSON interface} {
      type wired;
      check link yes;
      extended next hop yes;
      next hop prefer ipv6;
    };
  '') cfg.wiredInterfaces;

  meshInterfaces = ''
    interface "mesh-*" {
      type tunnel;
      hello interval 15 s;
      extended next hop yes;
      next hop prefer ipv6;
      rtt cost 256;
      rtt max 270 ms;
    };
    interface "cross-*" {
      type tunnel;
      rxcost 512;
      hello interval 15 s;
      extended next hop yes;
      next hop prefer ipv6;
      rtt cost 256;
      rtt max 270 ms;
    };
  '';
in
{
  options.profiles.bird = {
    wiredInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces for the wired Babel instance.";
    };

    enableMesh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable a separate Babel instance on the mesh-* and cross-* tunnel interfaces.";
    };

    advertiseIPv4DefaultRoute = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Import the kernel IPv4 default route and advertise it through the wired Babel instance.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open UDP port 6696 globally for Babel. Set to false to manage firewall rules in the host network module.";
    };
  };

  config = {
    assertions = [
      {
        assertion = advertiseIPv4DefaultRoute -> (cfg.wiredInterfaces != [ ]);
        message = "profiles.bird.advertiseIPv4DefaultRoute requires at least one wired Babel interface.";
      }
    ];

    services.bird = {
      enable = true;
      config = ''
        log syslog all;
        ipv6 sadr table sadr6;

        protocol device {
          scan time 10;
        }

        protocol direct {
          ipv4;
          ipv6 sadr;
          interface "lo", "vip";
        }

        protocol kernel kernel4 {${learn}
          metric 2048;
          merge paths on;
          ipv4 {
            import ${ipv4Import};
            export where source != RTS_DEVICE;
          };
        }

        protocol kernel kernel6 {${learn}
          metric 2048;
          merge paths on;
          ipv6 sadr {
            import none;
            export filter {
              if source = RTS_DEVICE then
                reject;
              krt_prefsrc = ${config.networking.ipv6Address};
              accept;
            };
          };
        }
      ''
      + lib.optionalString (cfg.wiredInterfaces != [ ]) (
        "\n" + babelProtocol wiredSources wiredInterfaces
      )
      + lib.optionalString cfg.enableMesh ("\n" + babelProtocol babelSources meshInterfaces);
    };

    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ 6696 ];

    systemd.network.config.networkConfig.ManageForeignRoutes = false;
  };
}
