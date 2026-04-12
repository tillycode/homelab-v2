{
  profiles.system.disko = {
    devices = [ "/dev/vda" ];
    legacyBoot = true;
    swapSize = null;
    growFileSystem = true;
  };

  fileSystems = {
    "/run/secrets/kubernetes.io/serviceaccount" = {
      device = "serviceaccount";
      fsType = "virtiofs";
      options = [ "ro,nofail" ];
    };
  };

  users.groups.virtiofs = {
    # in consistent with upstream kubevirt gid
    gid = 107;
  };
}
