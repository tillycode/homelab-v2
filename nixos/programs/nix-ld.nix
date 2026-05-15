{ pkgs, lib, ... }:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries =
    # for playwright
    lib.pipe pkgs.playwright-driver.browsers.entries [
      lib.attrValues
      (lib.concatMap (pkg: pkg.buildInputs or [ ]))
      (lib.map (pkg: pkg.lib or pkg.out or pkg))
    ];
}
