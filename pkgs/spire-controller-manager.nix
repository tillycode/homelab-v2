# copied from https://github.com/NickCao/nixpkgs/blob/b30bb8f7e88146832f536511df012afa3313dd66/pkgs/by-name/sp/spire-controller-manager/package.nix
{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  nix-update-script,
}:

buildGo127Module (finalAttrs: {
  pname = "spire-controller-manager";
  version = "0.8.1";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "spiffe";
    repo = "spire-controller-manager";
    tag = "v${finalAttrs.version}";
    hash = "sha256-70adk3G+GDJvfp7c+97PWLA05bgArgRD5lGAHvIdZVc=";
  };

  patches = [ ./go-mod-missing-winio.patch ];

  vendorHash = "sha256-nBttc6XMQvAYZLS3LeRBl+D0L43l/XzAHsYyZyfZpYg=";

  ldflags = [ "-s" ];

  subPackages = [ "cmd" ];

  postInstall = ''
    mv "$out/bin/cmd" "$out/bin/spire-controller-manager"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Kubernetes controller manager that reconciles workload registration and federation relationships";
    homepage = "https://github.com/spiffe/spire-controller-manager";
    changelog = "https://github.com/spiffe/spire-controller-manager/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ nickcao ];
    mainProgram = "spire-controller-manager";
  };
})
