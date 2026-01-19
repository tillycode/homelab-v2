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

  makeExtensibleCustomized =
    custom: attrs:
    lib.fix (
      self:
      (attrs self)
      // {
        extend = f: makeExtensibleCustomized custom (custom f attrs);
      }
    );
in
rec {
  # Given a directory, return a recursive attrset of paths which mirror the filesystem structure.
  # Files and directories that start with `_` are not included.
  # If a directory contains `default.nix`, it won't be recursed.
  # extendsRecursive =
  #   overlay: f: final:
  #   let
  #     prev = f final;
  #   in
  #   lib.recursiveUpdate prev (overlay final prev);
  listModules =
    src:
    makeExtensibleCustomized
      (
        f: attrs: final:
        let
          prev = attrs final;
        in
        lib.recursiveUpdate prev (lib.mapAttrsRecursive (p: mkImports) (lib.toExtension f final prev))
      )
      (
        self:
        lib.optionalAttrs (
          lib.pathExists src && lib.assertMsg (lib.pathType src == "directory") "src must be a directory"
        ) (_listModules src)
      );

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

  mkModules =
    modules:
    lib.pipe modules [
      (lib.flip lib.removeAttrs [ "extend" ])
      (lib.mapAttrsToListRecursive (
        p: v: {
          name = lib.concatStringsSep "." p;
          value = import v;
        }
      ))
      lib.listToAttrs
    ];
}
