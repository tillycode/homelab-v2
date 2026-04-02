{ lib, config, ... }:
let
  groupNamesToGid = lib.mapAttrs' (_: g: lib.nameValuePair g.name g.gid) config.users.groups;
in
{
  environment.etc =
    let
      autosubs = lib.pipe config.users.users [
        lib.attrValues
        (lib.filter (u: u.isNormalUser))
        (lib.concatMapStrings (
          u: "${toString u.uid}:${toString (100000 + (u.uid - 1000) * 65536)}:65536\n"
        ))
      ];
    in
    {
      "subuid".text = autosubs;
      "subuid".mode = "0444";
      "subgid".text = autosubs;
      "subgid".mode = "0444";
    };

  assertions = [
    {
      assertion = lib.pipe config.users.users [
        lib.attrValues
        (lib.filter (u: u.isNormalUser))
        (lib.all (u: u.name == u.group && u.uid != null && groupNamesToGid.${u.group} or null == u.uid))
      ];
      message = "every normal user must have a private group that has the same name and uid";
    }
  ];
}
