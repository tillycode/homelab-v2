{ pkgs, ... }:
let
  pkg = pkgs.tailscale.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      # Read CGNAT CIDR range from TS_CGNAT_RANGE environment variable if set
      (pkgs.fetchpatch {
        url = "https://github.com/sunziping2016/tailscale/commit/a3027f992d10b7be3148b04fbe685198445f1b6d.patch";
        hash = "sha256-RmfFLlucyKJzQwZxG2WwRG5ER3uIoj1qVVCYBH9g2bQ=";
      })
    ];
  });
in
{
  services.tailscale = {
    enable = true;
    package = pkg;
    openFirewall = true;
    extraDaemonFlags = [ "--no-logs-no-support" ];
  };

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/tailscale";
      mode = "0700";
    }
  ];

  # Limit tailscale to a smaller CIDR
  # For Aliyun DNS, and reduce the risk of conflicting with ISP's PPPoE IP
  systemd.services.tailscaled.environment = {
    TS_CGNAT_RANGE = "100.112.36.0/24";
  };
}
