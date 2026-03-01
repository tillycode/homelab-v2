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
  };
in
{
  config = {
    sops.defaultSopsFile = ../../secrets/hosts/${name}.yaml;
    sops.age.sshKeyPaths = [
      "${config.preservation.preserveAt.default.persistentStoragePath}/etc/ssh/ssh_host_ed25519_key"
    ];
    sops.gnupg.sshKeyPaths = [ ];
    sops.agePublicKey = agePublicKeys.${name};
  };

  options.sops.agePublicKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "The age public key for the secret encryption.";
  };
}
