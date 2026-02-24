{
  fetchFromGitHub,
  buildGoModule,
  lib,
  nix-update-script,
}:
buildGoModule (final: {
  pname = "dnsfmt";
  version = "0.8.0";
  src = fetchFromGitHub {
    owner = "miekg";
    repo = "dnsfmt";
    rev = "v${final.version}";
    sha256 = "sha256-9bAifsK6LO/ouV1ChyzhVmiN5MLQ18m9nViPD37QwGc=";
  };
  vendorHash = "sha256-DWrHwr+hc9JEKBlUMuGJFKzSzJ57zzjsX+1P3XZk92I=";
  # serial_test.go has a test that depends on the current time
  doCheck = false;
  meta = {
    description = "Auto format DNS zone files";
    homepage = "https://github.com/miekg/dnsfmt";
    mainProgram = "dnsfmt";
    license = with lib.licenses; [ agpl3Only ];
  };
  passthru = {
    updateScript = nix-update-script { };
  };
})
