{
  # CephCluster reports HEALTH_WARN if clock drift is larger than `mon_clock_drift_allowed`,
  # which defaults to 0.05 seconds.
  # See https://docs.ceph.com/en/squid/rados/configuration/mon-config-ref/#confval-mon_clock_drift_allowed.
  # We setup chrony to provide NTP services for the cluster.
  services.chrony.enable = true;
  services.chrony.extraConfig = ''
    allow 10.112.8.0/24
  '';

  networking.timeServers = [
    "0.cn.pool.ntp.org"
    "1.cn.pool.ntp.org"
    "2.cn.pool.ntp.org"
    "3.cn.pool.ntp.org"
  ];

  networking.firewall.interfaces.svc.allowedUDPPorts = [ 123 ];

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/chrony";
      mode = "0750";
      user = "chrony";
      group = "chrony";
    }
  ];
}
