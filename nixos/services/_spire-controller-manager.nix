{
  utils,
  lib,
  pkgs,
  config,
  ...
}:
let
  yaml = pkgs.formats.yaml { };
  entryOption = {
    freeformType = yaml.type;
    options = {
      spiffeID = lib.mkOption {
        type = lib.types.str;
        description = "The SPIFFE ID for the entry.";
      };
      parentID = lib.mkOption {
        type = lib.types.str;
        description = "The SPIFFE ID of the parent entry.";
      };
      selectors = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "The selectors for the entry.";
      };
    };
  };
in
{
  options.profiles.spire = {
    entries = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule entryOption);
      default = [ ];
      description = "The SPIRE entries to create for the controller manager.";
    };
  };
  config = {
    systemd.services.spire-controller-manager = {
      wantedBy = [ "multi-user.target" ];
      after = [ "spire-server.service" ];
      serviceConfig = {
        RestartSec = "5s";
        ExecStart = utils.escapeSystemdExecArgs [
          (lib.getExe pkgs.spire-controller-manager)
          "-config"
          (yaml.generate "spire-controller-manager.yaml" {
            apiVersion = "spire.spiffe.io/v1alpha1";
            kind = "ControllerManagerConfig";

            # metrics.bindAddress: 0.0.0.0:8082

            clusterName = "scm";
            clusterDomain = "local";
            trustDomain = "szp15.com";

            entryIDPrefix = "scm";

            spireServerSocketPath = "/run/spire/server/private/api.sock";
            staticManifestPath = pkgs.linkFarm "spire-manifests" (
              lib.mapAttrs' (name: entry: {
                name = "${name}.yaml";
                value = yaml.generate "entry.yaml" {
                  apiVersion = "spire.spiffe.io/v1alpha1";
                  kind = "ClusterStaticEntry";
                  spec = entry;
                };
              }) config.profiles.spire.entries
            );
          })
        ];
        User = "spire-server";
        Group = "spire-server";

        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivatePIDs = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";

        InaccessiblePaths = [
          "-/var/lib/spire/server"
          "-${config.preservation.preserveAt.default.persistentStoragePath}/var/lib/spire/server"
        ];

        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
      };
    };
  };
}
