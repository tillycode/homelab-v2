{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "swan-updown";
  version = "0.3.1-unstable-2026-07-13";
  src = fetchFromGitHub {
    owner = "6-6-6";
    repo = "swan-updown";
    rev = "1629fbc02c3d70276576330b9060a815146485d8";
    hash = "sha256-22RthqQa3/nXIBoHeGezqvS4qscm+qS3/iIi9YFJLTk=";
  };
  cargoHash = "sha256-RL8Co2qej3LFSxcLkENL7oB7g3U0BRz6Lxj9y/GbC2M=";
  meta = {
    desription = "swan-updown helps create XFRM interfaces on demand";
    homepage = "https://github.com/6-6-6/swan-updown";
    mainProgram = "swan-updown";
    license = with lib.licenses; [ mit ];
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
