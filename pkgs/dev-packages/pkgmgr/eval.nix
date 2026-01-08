{
  importPath,
}:
let
  inherit (builtins)
    attrNames
    parseDrvName
    isList
    concatMap
    ;
  toList = x: if isList x then x else [ x ];
  isDerivation = value: value.type or null == "derivation";
  mapDerivationToListRecursive =
    f: set:
    let
      mapRecursive =
        path: value:
        if isDerivation value then
          [ (f path value) ]
        else if value.recurseForDerivations or false then
          recurse path value
        else
          [ ];
      recurse = path: set: concatMap (name: mapRecursive (path ++ [ name ]) set.${name}) (attrNames set);
    in
    recurse [ ] set;
  splitDot = s: builtins.filter builtins.isString (builtins.split "\\." (toString s));

  packages = import importPath { };
  getScript = pkg: pkg.updateScript or null;
  extract =
    path: pkg:
    let
      updateScript = getScript pkg;
    in
    {
      name = pkg.name;
      pname = pkg.pname or (parseDrvName pkg.name).name;
      version = pkg.version or (parseDrvName pkg.name).version;
      updateScript =
        if updateScript == null then
          null
        else
          map builtins.toString (toList (updateScript.command or updateScript));
      supportedFeatures = updateScript.supportedFeatures or [ ];
      attrPath = if updateScript ? attrPath then splitDot updateScript.attrPath else path;
    };
in
mapDerivationToListRecursive extract packages
