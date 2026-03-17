{
  services.openbao-proxy = {
    enable = true;

    settings = {
      vault.address = "https://vault.szp15.com";
      log_level = "debug";

      auto_auth = {
        method = [
          {
            type = "kubernetes";
            config.role = "ai";
          }
        ];
        sinks = [
          {
            sink = {
              type = "file";
              config.path = "/run/openbao-proxy/token";
            };
          }
        ];
      };

      api_proxy.use_auto_auth_token = true;

      listener = [
        {
          type = "unix";
          address = "/run/openbao-proxy/openbao-proxy.sock";
          # FIXME: socket_mode does not work when socket_user and socket_group care unset
          #     see https://github.com/openbao/openbao/issues/2594.
          socket_mode = "660";
          tls_disable = true;
        }
      ];
    };
  };
}
