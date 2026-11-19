{
  networking.nftables.enable = true;

  # IPsec overlay network has dynmaic routing protocol.
  # Asymmetric routing is very common.
  networking.firewall.checkReversePath = "loose";
}
