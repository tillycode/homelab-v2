{ lib, ... }:
{
  options.services.rke2.cni = lib.mkOption {
    type =
      with lib.types;
      nullOr (enum [
        "multus,calico"
        "multus,canal"
        "multus,cilium"
        "multus,flannel"
      ]);
  };
}
