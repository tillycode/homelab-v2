{
  preservation.enable = true;
  preservation.preserveAt.default = {
    commonMountOptions = [
      "x-gvfs-hide"
      "x-gdu.hide"
    ];
    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
      {
        file = "/var/lib/systemd/random-seed";
        how = "symlink";
        inInitrd = true;
        configureParent = true;
      }
    ];
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"
      "/var/lib/nixos"
      "/var/log"
    ];
  };

  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
}
