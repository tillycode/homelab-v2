{

  fetchFromGitHub,
  buildGoModule,
  lib,
  nix-update-script,
}:
buildGoModule (final: {
  pname = "bbolt";
  version = "1.4.3";
  src = fetchFromGitHub {
    owner = "etcd-io";
    repo = "bbolt";
    rev = "v${final.version}";
    hash = "sha256-awBkr2ObRxPQkMlfVFZxEbQ9JQJsFrJvSBHtqP4Hb3I=";
  };
  vendorHash = "sha256-TzVmAMrNrNkFE9jQ+SILJXvbhBK1WenNPqA0FfuDU+M=";
  subPackages = [ "cmd/bbolt" ];
  passthru.updateScript = nix-update-script { };
  meta = {
    description = "An embedded key/value database for Go";
    homepage = "https://github.com/etcd-io/bbolt";
    license = lib.licenses.mit;
  };
})
