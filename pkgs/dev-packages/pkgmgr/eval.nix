{
  importPath,
  pkgs ? import <nixpkgs> { },
  predicate ? p: pkg: true,
  attrPathsJSON ? null,
  eval ? false,
}:
let
  lib = pkgs.lib;
  attrPaths = if attrPathsJSON == null then null else builtins.fromJSON attrPathsJSON;
  filterDerivation =
    p: v: predicate p v && (attrPaths == null || builtins.elem (lib.concatStringsSep "." p) attrPaths);
  mapDerivationToListRecursive =
    predicate: f: set:
    let
      mapRecursive =
        p: v:
        lib.optional (lib.isDerivation v && predicate p v) (f p v)
        ++ lib.optionals (v.recurseForDerivations or false) (recurse p v);
      recurse = p: v: builtins.concatMap (name: mapRecursive (p ++ [ name ]) v.${name}) (lib.attrNames v);
    in
    recurse [ ] set;
  extract =
    p: pkg:
    let
      updateScript = pkg.updateScript or null;
    in
    {
      name = pkg.name;
      pname = pkg.pname or (builtins.parseDrvName pkg.name).name;
      version = pkg.version or (builtins.parseDrvName pkg.name).version;
      updateScript =
        if updateScript == null then
          null
        else
          map toString (lib.toList (updateScript.command or updateScript));
      supportedFeatures = updateScript.supportedFeatures or [ ];
      attrPath = if updateScript ? attrPath then lib.splitString "." updateScript.attrPath else p;
    };
  packages = import importPath { inherit pkgs; };
  output = {
    nixpkgs = pkgs.path;
    packages = mapDerivationToListRecursive filterDerivation extract packages;
  };
in
if eval then output else pkgs.writeText "evaluation.json" (builtins.toJSON output)
