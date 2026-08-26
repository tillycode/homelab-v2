{
  fetchFromGitHub,
  buildGoModule,
  lib,
  nix-update-script,
}:
buildGoModule (final: {
  pname = "zteonu";
  version = "0.1.3";
  src = fetchFromGitHub {
    owner = "Septrum101";
    repo = "zteOnu";
    rev = "v${final.version}";
    hash = "sha256-SJahYl8ncjRFDsILySu5uk6qKipb2mC8ZVYa7dXKGP0=";
  };
  vendorHash = "sha256-Y2QxtmLUjweRr7C3XkJZGD6G7q/PCHmc/MhIQvWEfRw=";
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
