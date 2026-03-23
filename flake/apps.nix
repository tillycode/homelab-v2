{ self, lib, ... }:
let
  qcow2Images = [ "kubevm" ];
  inherit (self) nixosConfigurations;
in
{
  perSystem =
    { system, ... }:
    {
      apps = (
        lib.genAttrs'
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
      );
    };
}
