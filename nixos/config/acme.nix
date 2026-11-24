{
  security.acme = {
    acceptTerms = true;
    defaults.email = "me@szp.io";
  };

  preservation.preserveAt.default.directories = [
    {
      directory = "/var/lib/acme";
      user = "acme";
      group = "acme";
      mode = "0755";
    }
  ];
}
