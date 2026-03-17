{
  fetchFromGitHub,
  buildGoModule,
  lib,
  nix-update-script,
}:
buildGoModule (final: {
  pname = "vault-plugin-secrets-github";
  version = "2.3.2";
  src = fetchFromGitHub {
    owner = "martinbaillie";
    repo = "vault-plugin-secrets-github";
    rev = "v${final.version}";
    sha256 = "sha256-RAV4TevqfWvqrhc1/t9k+Sk5AJkbjceYcVXMj1qcKvo=";
  };
  vendorHash = "sha256-YELxGfVh2XVt7DXeISZg7/uf9B+/zEa43TTCTVHON4g=";
  ldflags = [
    "-s"
    "-w"
    "-X github.com/martinbaillie/vault-plugin-secrets-github/v2/github.projectName=${final.pname}"
    "-X github.com/martinbaillie/vault-plugin-secrets-github/v2/github.projectDocs=${final.meta.homepage}"
    "-X github.com/martinbaillie/vault-plugin-secrets-github/v2/github.projectVersion=v${final.version}"
    "-X github.com/prometheus/common/version.BuildDate=1970-01-01T01:01:01Z"
    "-X github.com/prometheus/common/version.Revision=${final.src.rev}"
    "-X github.com/prometheus/common/version.Version=${final.version}"
    "-X github.com/prometheus/common/version.Branch=master"
    "-X github.com/prometheus/common/version.BuildUser=unknown"
  ];
  postInstall = ''
    dir=$out/libexec/vault-plugins
    mkdir -p $dir
    mv $out/bin/* $dir/
    rmdir $out/bin
  '';
  meta = {
    description = "Create ephemeral, finely-scoped github access tokens using HashiCorp Vault";
    homepage = "https://github.com/martinbaillie/vault-plugin-secrets-github";
    license = with lib.licenses; [ asl20 ];
  };
  passthru = {
    updateScript = nix-update-script { };
  };
})
