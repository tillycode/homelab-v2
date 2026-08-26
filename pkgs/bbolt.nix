{

  fetchFromGitHub,
  buildGoModule,
  lib,
  nix-update-script,
}:
buildGoModule (final: {
  pname = "bbolt";
  version = "1.5.0";
  src = fetchFromGitHub {
    owner = "etcd-io";
    repo = "bbolt";
    rev = "v${final.version}";
    hash = "sha256-y48QXeffXBNBEsScMTSWQnXVG7xCZEAbAGKyfzl9m4Q=";
  };
  vendorHash = "sha256-Tp6IINFK8SR2AIqEeMP3qK2f90EpLPMibFATG3j9VKs=";
  subPackages = [ "cmd/bbolt" ];
  passthru.updateScript = nix-update-script { };
  meta = {
    description = "An embedded key/value database for Go";
    homepage = "https://github.com/etcd-io/bbolt";
    license = lib.licenses.mit;
  };
})
