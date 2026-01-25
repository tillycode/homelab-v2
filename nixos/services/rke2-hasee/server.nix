{
  imports = [ ./_common.nix ];
  services.rke2 = {
    role = "server";
    serverAddr = "https://10.112.8.100:9345";
  };
}
