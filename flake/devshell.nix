{ self, ... }:
let
  modules = self.lib.listModules ../devshell;
in
{
  perSystem = {
    devshells.default = {
      imports = self.lib.mkImports modules;
    };
  };
}
