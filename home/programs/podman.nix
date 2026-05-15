{ config, ... }:
{
  home.sessionVariables = {
    REGISTRY_AUTH_FILE = "${config.xdg.configHome}/containers/auth.json";
  };
}
