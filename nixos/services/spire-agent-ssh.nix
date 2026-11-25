{
  imports = [
    ./_spire-agent-common.nix
  ];
  services.spire.agent.settings.plugins.NodeAttestor.sshpop = {
    plugin_data = {
      host_key_path = "$CREDENTIALS_DIRECTORY/host_key";
      host_cert_path = "$CREDENTIALS_DIRECTORY/host_cert.pub";
    };
  };

  systemd.services.spire-agent.serviceConfig.LoadCredential = [
    "host_key:/etc/ssh/ssh_host_ed25519_key"
    "host_cert.pub:/etc/ssh/ssh_host_ed25519_key-cert.pub"
  ];
}
