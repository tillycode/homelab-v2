{
  security.acme = {
    acceptTerms = true;
    defaults.email = "me@szp.io";
  };

  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
  };

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/acme";
      user = "acme";
      group = "acme";
    }
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
