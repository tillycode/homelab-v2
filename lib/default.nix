{ inputs, lib, ... }:
lib.makeExtensible (self: {
  # Given a directory, return a recursive attrset of paths which mirror the filesystem structure.
  # Files and directories that start with `_` are not included.
  # This is primarily intended for constructing `nixosConfigurations`.
  listProfiles =
    src:
    inputs.haumea.lib.load {
      inherit src;
      loader = inputs.haumea.lib.loaders.path;
    };

  # Similar to listProfiles, but return a flattened list of paths instead.
  # This is for importing modules.
  listModules = src: lib.collect lib.isPath (self.listProfiles src);
})
