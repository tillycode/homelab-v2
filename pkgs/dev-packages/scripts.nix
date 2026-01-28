{
  python3Packages,
  lib,
  runCommandLocal,
}:
let
  pyproject = lib.importTOML ./pyproject.toml;
  pname = pyproject.project.name;
  inherit (pyproject.project) version;
  build-system = [ python3Packages.uv-build ];
  dependencies = with python3Packages; [
    pyyaml
  ];
  scripts = python3Packages.buildPythonApplication {
    inherit pname version;
    src = ./.;
    pyproject = true;
    inherit build-system dependencies;
    passthru = {
      editable = python3Packages.mkPythonEditablePackage {
        inherit
          pname
          version
          build-system
          dependencies
          ;
        root = "$PRJ_ROOT/pkgs/dev-packages";
        inherit (pyproject.project) scripts;
      };
      updateScript = null;
      inherit checkGeneratedHostSecrets;
    };
  };
  hostSecretRequests = flake: import ./scripts/secretmgr-eval.nix { inherit flake; };
  checkGeneratedHostSecrets =
    { flake }:
    runCommandLocal "generated-host-secrets"
      {
        src = flake;
        hostSecretRequests = builtins.toJSON (hostSecretRequests flake);
        passAsFile = [ "hostSecretRequests" ];
      }
      ''
        env
        cd "$src"
        ${lib.getExe' scripts "secretmgr"} status \
          --host-secret-requests-path "$hostSecretRequestsPath" \
          --check
        touch "$out"
      '';
in
scripts
