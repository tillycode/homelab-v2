{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.networking;
  ipv4 = {
    parse =
      address:
      let
        parts = map lib.toInt (lib.splitString "." address);
      in
      assert lib.assertMsg (
        builtins.length parts == 4 && lib.all (x: x >= 0 && x <= 255) parts
      ) "Invalid IPv4 address: ${address}";
      [ (lib.foldl (value: part: value * 256 + part) 0 parts) ];
    format =
      address:
      let
        value = builtins.head address;
      in
      lib.concatStringsSep "." (
        map toString [
          (builtins.div value 16777216)
          (builtins.div (lib.mod value 16777216) 65536)
          (builtins.div (lib.mod value 65536) 256)
          (lib.mod value 256)
        ]
      );
  };
  ipv6 = {
    parse =
      address:
      let
        parts = map lib.fromHexString (lib.splitString ":" (lib.network.ipv6.fromString address).address);
      in
      builtins.genList (i: builtins.elemAt parts (2 * i) * 65536 + builtins.elemAt parts (2 * i + 1)) 4;
    format =
      address:
      lib.concatStringsSep ":" (
        map (
          part:
          lib.toLower "${lib.toHexString (builtins.div part 65536)}:${lib.toHexString (lib.mod part 65536)}"
        ) address
      );
  };
  add =
    address: offset:
    let
      result =
        lib.foldr
          (
            part: acc:
            let
              sum = part + acc.carry;
            in
            {
              carry = builtins.div sum 4294967296;
              address = [ (lib.mod sum 4294967296) ] ++ acc.address;
            }
          )
          {
            carry = offset;
            address = [ ];
          }
          address;
    in
    assert lib.assertMsg (result.carry == 0) "Address overflow";
    result.address;
  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);
  mask =
    length: prefix:
    lib.genList (
      i:
      if (i + 1) * 32 <= prefix then
        4294967295
      else if i * 32 >= prefix then
        0
      else
        4294967296 - (pow2 ((i + 1) * 32 - prefix))
    ) length;

  parseCidr =
    family: cidr:
    let
      parts = lib.splitString "/" cidr;
      address = family.parse (builtins.head parts);
      prefix = lib.toInt (builtins.elemAt parts 1);
    in
    assert lib.assertMsg (
      builtins.length parts == 2 && prefix >= 0 && prefix <= lib.length address * 32
    ) "Invalid router CIDR: ${cidr}";
    {
      start = address;
      prefix = prefix;
    };
  bitAnd = lib.zipListsWith builtins.bitAnd;
  allocate =
    family: cidr:
    let
      subnet = parseCidr family cidr;
      netMask = mask (lib.length subnet.start) subnet.prefix;
      address = add subnet.start cfg.index;
    in
    assert lib.assertMsg (
      cfg.index >= 0 && bitAnd address netMask == bitAnd subnet.start netMask
    ) "Router index ${toString cfg.index} is outside CIDR ${cidr}";
    family.format address;
in
{
  options.networking = {
    index = mkOption {
      type = types.int;
      description = "Host index";
    };
    ipv4Address = mkOption {
      type = types.str;
      description = "IPv4 addresses for the host";
    };
    ipv6Address = mkOption {
      type = types.str;
      description = "IPv6 addresses for the host";
    };
    ipam = {
      enable = mkEnableOption "IPAM";
      ipv4Pool = mkOption {
        type = types.str;
        description = "IPv4 CIDR for all routers";
      };
      ipv6Pool = mkOption {
        type = types.str;
        description = "IPv6 CIDR for all routers";
      };
    };
  };

  config = lib.mkIf cfg.ipam.enable {
    networking = {
      ipv4Address = lib.mkDefault (allocate ipv4 cfg.ipam.ipv4Pool);
      ipv6Address = lib.mkDefault (allocate ipv6 cfg.ipam.ipv6Pool);
    };
    systemd.network.networks."40-loopback" = {
      name = "lo";
      address = [
        "${cfg.ipv4Address}/32"
        "${cfg.ipv6Address}/128"
      ];
    };
  };
}
