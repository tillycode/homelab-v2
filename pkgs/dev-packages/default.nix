{
  lib,
  newScope,
}:
lib.makeScope newScope (
  self:
  let
    inherit (self) callPackage;
  in
  {
    scripts = callPackage ./scripts.nix { };
    cache = callPackage ./cache.nix { };
  }
)
