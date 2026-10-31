{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dnsmasq-china-list";
  version = "0-unstable-2026-10-30";
  src = fetchFromGitHub {
    owner = "felixonmars";
    repo = "dnsmasq-china-list";
    rev = "a8942d3ac6ebd8dcfc582d4e97fbb443a2176cb2";
    hash = "sha256-OASQKxmWx6Hwi398wedEt1ceqsM+Pv7b0fGms+twnlo=";
  };
  buildPhase = ''
    runHook preBuild
    make raw
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp *.raw.txt $out
    runHook postInstall
  '';
  meta = {
    description = "Chinese-specific configuration to improve your favorite DNS server. Best partner for chnroutes.";
    homepage = "https://github.com/felixonmars/dnsmasq-china-list";
    license = with lib.licenses; [ wtfpl ];
  };
  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--version"
        "branch"
      ];
    };
  };
})
