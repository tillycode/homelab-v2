{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "auto-allocate-uids"
    ];

    auto-allocate-uids = true;
    auto-optimise-store = true;
    min-free = 1024 * 1024 * 1024; # 1GiB
    sandbox = true;

    allowed-users = [ "@users" ];
    trusted-users = [ "@wheel" ];

    keep-outputs = true;
    keep-derivations = true;

    use-xdg-base-directories = true;
  };

  nix.channel.enable = false;
}
