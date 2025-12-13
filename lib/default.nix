{ lib, ... }:
let
  _listModules =
    dir:
    let
      children = builtins.readDir dir;
    in
    if children."default.nix" or null == "regular" then
      dir
    else
      lib.concatMapAttrs (
        name: type:
        if lib.hasPrefix "_" name then
          { }
        else if type == "directory" then
          {
            ${name} = _listModules (dir + "/${name}");
          }
        else if type == "regular" && lib.hasSuffix ".nix" name then
          {
            ${lib.removeSuffix ".nix" name} = dir + "/${name}";
          }
        else
          { }
      ) children;
in
lib.makeExtensible (self: {
  # Given a directory, return a recursive attrset of paths which mirror the filesystem structure.
  # Files and directories that start with `_` are not included.
  # If a directory contains `default.nix`, it won't be recursed.
  listModules =
    src:
    let
      type = lib.pathType src;
    in
    if !lib.pathExists src then
      { }
    else if type == "regular" then
      src
    else if type == "directory" then
      _listModules src
    else
      { };

  # Given a nested list of nest attrsets of paths, return a flattened paths
  #
  # a typical usages is like
  # let
  #   modules = lib.listModules ./modules;
  #   profiles = with modules {
  #     basic = [
  #       services.foo
  #     ];
  #     desktop = [
  #       profiles.basic
  #       services.bar
  #     ];
  #   }
  # in
  # {
  #   imports = lib.mkImports [
  #     profiles.desktop
  #   ];
  # }
  mkImports =
    modules:
    lib.pipe modules [
      lib.flatten
      (lib.concatMap (lib.collect lib.isPath))
      lib.unique
    ];

  mkImported =
    modules:
    if lib.isAttrs modules then
      lib.mapAttrsRecursive (_: path: import path) modules
    else
      import modules;
})
