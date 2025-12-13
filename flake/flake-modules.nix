{ self-lib, ... }:
let
  flakeModules = self-lib.listModules ../flake-modules;
in
{
  imports = self-lib.mkImports flakeModules;
  flake.flakeModules = self-lib.mkImported flakeModules;
}
