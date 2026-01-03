{ pkgs, ... }:
{
  programs.htop = {
    enable = true;
    settings = {
      show_program_path = 0;
      highlight_base_name = 1;
      highlight_changes = 1;
      tree_view = 1;
      hide_kernel_threads = 1;
      hide_userland_threads = 1;
    };
  };

  programs.tcpdump.enable = true;
  programs.mtr.enable = true;

  environment.systemPackages = with pkgs; [
    # network
    ethtool
    nftables
    dnsutils
    openssl
    btop

    # data processing
    jq
    yq-go

    # system management
    file
    lsof
    killall
    rsync
    strace
    binutils
    pciutils
    usbutils
    bpftools
    sysstat

    # RIIR tools
    fd
    ripgrep
    dust
  ];
}
