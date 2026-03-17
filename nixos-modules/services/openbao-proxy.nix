{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.openbao-proxy;
  settingsFormat = pkgs.formats.json { };
in
{
  options = {
    services.openbao-proxy = {
      enable = lib.mkEnableOption "OpenBao proxy daemon";
      package = lib.mkPackageOption pkgs "openbao" {
        example = "pkgs.openbao.override { withHsm = false; withUi = false; }";
      };
      settings = lib.mkOption {
        description = ''
          Settings of OpenBao proxy.

          See [documentation](https://openbao.org/docs/agent-and-proxy/proxy/) for more details.
        '';
        type = lib.types.submodule {
          freeformType = settingsFormat.type;
        };
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Additional arguments given to OpenBao proxy.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.openbao-proxy = {
      description = "OpenBao - A tool to perform automatic authentication";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "proxy"
            "-config"
            (settingsFormat.generate "openbao-proxy.hcl.json" cfg.settings)
          ]
          ++ cfg.extraArgs
        );
        ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -SIGHUP $MAINPID";
        StateDirectory = "openbao-proxy";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "openbao-proxy";
        RuntimeDirectoryMode = "0750";
        CapabilityBoundingSet = "";
        User = "openbao-proxy";
        Group = "openbao-proxy";
        LimitCORE = 0;
        LockPersonality = true;
        MemorySwapMax = 0;
        MemoryZSwapMax = 0;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        Restart = "on-failure";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "@resources"
          "~@privileged"
        ];
        UMask = "0007";
      };
    };

    users.users.openbao-proxy = {
      isSystemUser = true;
      group = "openbao-proxy";
      home = "/var/lib/openbao-proxy";
      extraGroups = [ "virtiofs" ];
    };
    users.groups.openbao-proxy = { };
  };
}
