{
  fetchFromGitHub,
  buildGoModule,
  lib,
  nix-update-script,
}:
buildGoModule (final: {
  pname = "zteonu";
  version = "0.0.7";
  src = fetchFromGitHub {
    owner = "Septrum101";
    repo = "zteOnu";
    rev = "v${final.version}";
    sha256 = "sha256-irw7q64MO9xdL0RXWnWN3ULkHqCGBWuYlsMl7avgfQI=";
  };
  vendorHash = "sha256-tecWPrGGCFmWGjeMA7ct3Vvm85A41dskjx2ntv5cIl8=";
  meta = {
    description = "A tool that can open ZTE onu device factory mode";
    mainProgram = "zteOnu";
    homepage = "https://github.com/Septrum101/zteOnu";
    license = with lib.licenses; [ agpl3Only ];
  };
  passthru = {
    updateScript = nix-update-script { };
  };
})
