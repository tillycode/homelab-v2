{ lib, self, ... }:
let
  prefix = "spiffe://szp15.com";
  spireServer = "${prefix}/spire/server";
  sshNodes = lib.pipe self.nixosConfigurations [
    lib.attrValues
    (lib.filter (
      x: lib.hasAttrByPath [ "plugins" "NodeAttestor" "sshpop" ] x.config.services.spire.agent.settings
    ))
    (map (x: x.config.system.name))
  ];
  nodeSelectors =
    lib.mapAttrs (_: x: "tpm:pub_hash:${x}") (import ./_spire-tpm-pub-hashes.nix)
    // lib.genAttrs sshNodes (x: "spiffe_id:${prefix}/spire/agent/sshpop/static/${x}");

  tags = {
    any = lib.attrNames nodeSelectors;
    desktop = [
      "desktop"
      "laptop"
    ];
  };
in
{
  profiles.spire.entries =
    # nodes
    (lib.concatMapAttrs (name: selector: {
      "nodes-name-${name}" = {
        parentID = spireServer;
        spiffeID = "${prefix}/nodes/${name}";
        selectors = [ selector ];
      };
    }) nodeSelectors)
    # node tags
    // lib.concatMapAttrs (
      tag: nodes:
      lib.genAttrs' nodes (name: {
        name = "nodes-tag-${tag}-${name}";
        value = {
          parentID = spireServer;
          spiffeID = "${prefix}/nodes/tags/${tag}";
          selectors = [ nodeSelectors.${name} ];
        };
      })
    ) tags
    // {
      user-sun = {
        parentID = "${prefix}/nodes/tags/desktop";
        spiffeID = "${prefix}/users/sun";
        selectors = [
          "systemd:id:user@1000.service"
          "unix:user:sun"
        ];
      };
    };
}
