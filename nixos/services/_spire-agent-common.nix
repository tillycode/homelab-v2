{
  services.spire.agent = {
    enable = true;
    settings = {
      agent = {
        rebootstrap_mode = "auto";
        trust_domain = "szp15.com";
        server_address = "spire.szp15.com";
        trust_bundle_url = "https://spire.szp15.com";
        trust_bundle_format = "spiffe";
      };
      plugins = {
        KeyManager.memory = { };
        WorkloadAttestor.unix = { };
        WorkloadAttestor.systemd = { };
      };
    };
  };

  systemd.services.spire-agent = {
    serviceConfig = {
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };
}
