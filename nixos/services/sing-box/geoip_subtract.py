import json
import sys
from collections.abc import Generator
from ipaddress import IPv4Network, IPv6Network, ip_network


def exclude_cidr(
    cidr: IPv4Network | IPv6Network,
    exclude_cidr: IPv4Network | IPv6Network,
) -> Generator[IPv4Network | IPv6Network]:
    if cidr.version != exclude_cidr.version:
        yield cidr
    elif exclude_cidr.subnet_of(cidr):  # pyright: ignore[reportArgumentType]
        yield from cidr.address_exclude(exclude_cidr)  # pyright: ignore[reportArgumentType]
    elif not cidr.subnet_of(exclude_cidr):  # pyright: ignore[reportArgumentType]
        yield cidr


geoip = json.load(sys.stdin)
ip_cidrs = [ip_network(i) for i in geoip["rules"][0]["ip_cidr"]]
for x in sys.argv[1:]:
    exclude = ip_network(x)
    ip_cidrs = [i for ip_cidr in ip_cidrs for i in exclude_cidr(ip_cidr, exclude)]
geoip["rules"][0]["ip_cidr"] = [str(i) for i in ip_cidrs]
json.dump(geoip, sys.stdout, indent=2)
