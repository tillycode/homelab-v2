{
  imports = [ ./_common.nix ];
  services.rke2 = {
    role = "server";
    serverAddr = "https://10.112.8.2:9345";
  };
}
