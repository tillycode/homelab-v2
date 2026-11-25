{ lib, pkgs, ... }:
{
  imports = [
    ./_spire-agent-common.nix
  ];
  services.spire.agent.settings.plugins.NodeAttestor.tpm = {
    plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_agent";
    plugin_data = { };
  };
}
