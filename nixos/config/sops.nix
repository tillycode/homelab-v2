# This module is read by the secretmgr to generate secrets for the host.
{ config, lib, ... }:
let
  inherit (config.system) name;
  agePublicKeys = {
    hasee01 = "age1etar9rrla2d79jfvmsqdzkag0dtjvzh7xf3zdlc5z3k53k6ncf3qthf8gp";
    hasee02 = "age1fgz58ufhqxwvush0k26kajeamd3meh7ufy92vqd4yj9cup0dduls7dv9uc";
    hasee03 = "age1mg0y7kd0zcggy9ukze4sg2drmaafdrwjs4zzqvzhznzhmhtw3a5serua3g";
    hgh0 = "age128juh5n7pxuw2ltmw434m4tw7s8vk6t44amfa4dw495rkyeqmfcq4vt0wh";
    router = "age1dtdquu63vrxag5pgs4yrqaarjywuksnw4nz2dq5t44v8tv24cy8qz7yfcn";
    desktop = "age1v6lnkm7prm0dpmcdpvn44v50rpfkzsed5uv3znxt4grsd5y6sv5qjru9qq";
    sjc1 = "age1lcvusytmzf9h776njea7qnyfs3pn37rj0ngxvr7er6pgk3tm3a5qm2j9nd";
    laptop = "age1kgcxdnuy9fxtcf6fp7camk6tqm0fset0jvvh9760rqmrkmx99v0q2c7w8e";
    lax0 = "age13d4sy7r99z8sp9djvzrtvq374nfqavl5p3w508mt7jyur78ne9kqey22hc";
    hkg0 = "age1cru74y44p9ehwwpw7gvrjqdmgea755wxnu8r8hm3pu0de60pmegqtu2alp";
    hkg1 = "age1luzh4jd30clz0f0av5wkaf45wr30zu8x45p8ak0meu9e83wkgqssecrdwq";
  };
in
{
  config = {
    sops.defaultSopsFile = ../../secrets/hosts/${name}.yaml;
    sops.age.sshKeyPaths = [
      "${config.preservation.preserveAt.default.persistentStoragePath}/etc/ssh/ssh_host_ed25519_key"
    ];
    sops.gnupg.sshKeyPaths = [ ];
    sops.agePublicKey = agePublicKeys.${name} or null;
  };

  options.sops.agePublicKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "The age public key for the secret encryption.";
  };
}
