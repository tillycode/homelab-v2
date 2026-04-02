{ pkgs, ... }:
{
  ## ---------------------------------------------------------------------------
  ## CONFIGURATION
  ## ---------------------------------------------------------------------------
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerSocket.enable = true;
    dockerCompat = true;
  };

  ## ---------------------------------------------------------------------------
  ## CLI
  ## ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [ docker-compose ];

  ## ---------------------------------------------------------------------------
  ## PERSISTENCE
  ## ---------------------------------------------------------------------------
  preservation.preserveAt.default.directories = [
    "/var/lib/containers"
  ];
}
