{
  self,
  lib,
  inputs,
  ...
}:
let
  qcow2Images = [ "kubevm" ];
  inherit (self) nixosConfigurations;
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages.github-action-nix-store-cache = pkgs.closureInfo {
        rootPaths = lib.attrValues (lib.removeAttrs inputs [ "self" ]);
      };
      apps =
        (lib.genAttrs'
          (lib.filter (
            name:
            lib.hasAttr name nixosConfigurations
            && system == nixosConfigurations.${name}.config.nixpkgs.hostPlatform.system
          ) qcow2Images)
          (name: {
            name = "generate-${name}-image";
            value.program = "${nixosConfigurations.${name}.config.system.build.diskoImagesScript}";
            value.meta.description = "Generate ${name} image";
          })
        )
        // {
          github-actions-build-push = {
            meta.description = "Build all flake checks and push them to https://cache.szp.io";
            program = lib.getExe (
              pkgs.writeShellApplication {
                name = "github-actions-build-push";
                runtimeInputs = with pkgs; [
                  curl
                ];
                text = ''
                  mkdir -p ~/.config/niks3
                  umask 077
                  curl -fsS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
                    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://niks3.szp.io" | jq -re '.value' > ~/.config/niks3/auth-token
                  curl -fsS https://niks3.szp.io/api/gc/status -H "Authorization: Bearer $(cat ~/.config/niks3/auth-token)" | jq .
                '';
              }
            );

          };
        };
    };
}
