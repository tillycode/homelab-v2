import argparse
import base64
import io
import math
import re
import secrets
import sys
import tarfile
import uuid
from functools import cache
from gzip import GzipFile
from pathlib import Path
from typing import BinaryIO, Literal
from urllib.parse import quote_plus

import yaml
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from pydantic import Base64Bytes, BaseModel, ConfigDict, Field


class Server(BaseModel):
    model_config = ConfigDict(extra="forbid")
    # Primary key. Matches to the hostName. Used for key derivation.
    name: str
    # Appears in the subscription. Defaults to `server`
    display_name: str | None = None
    # The server address. Defaults to `name`
    server: str | None = None


class User(BaseModel):
    model_config = ConfigDict(extra="forbid")
    # Primary key. Used for key derivation.
    name: str
    # Display name for log. Defaults to `name`
    display_name: str | None = None


# python 3.14 has a constant for nil UUID
NIL = uuid.UUID("00000000-0000-0000-0000-000000000000")


class Source(BaseModel):
    model_config = ConfigDict(extra="forbid")
    namespace: uuid.UUID = NIL  # for legacy support
    primary_key: Base64Bytes = Field(min_length=4 * math.ceil(32 / 3))
    servers: list[Server] = []
    users: list[User] = []


@cache
def generate_server_private_key(primary_key: bytes, server_name: str) -> bytes:
    key = bytearray(
        HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=primary_key,
            info=b"server-private-key",
        ).derive(server_name.encode())
    )
    # curve25519 clamping
    key[0] &= 248
    key[31] = (key[31] & 127) | 64
    return bytes(key)


@cache
def generate_public_key(private_key: bytes) -> bytes:
    key = X25519PrivateKey.from_private_bytes(private_key)
    return key.public_key().public_bytes_raw()


@cache
def generate_user_uuid(
    primary_key: bytes, server_name: str, user_name: str
) -> uuid.UUID:
    key = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=primary_key,
        info=b"user-uuid",
    ).derive(f"{server_name}:{user_name}".encode())
    return uuid.uuid5(NIL, key)


@cache
def generate_short_id(primary_key: bytes, server_name: str, user_name: str) -> str:
    key = HKDF(
        algorithm=hashes.SHA256(),
        length=8,
        salt=primary_key,
        info=b"short-id",
    ).derive(f"{server_name}:{user_name}".encode())
    return key.hex()


class VLESSUser(BaseModel):
    name: str
    uuid: uuid.UUID
    flow: str = "xtls-rprx-vision"


class Handshake(BaseModel):
    server: str = "::1"
    server_port: int = 40100


class UTLS(BaseModel):
    enabled: bool = True


class Reality(BaseModel):
    enabled: bool = True
    handshake: Handshake | None = None
    private_key: str | None = None
    public_key: str | None = None
    short_id: str | list[str] | None = None


class TLS(BaseModel):
    enabled: bool = True
    server_name: str
    utls: UTLS | None = None
    reality: Reality


class VLESSInbound(BaseModel):
    type: str = "vless"
    tag: str = "vless"
    listen: str = "::"
    listen_port: int = 443
    users: list[VLESSUser] | None = None
    tls: TLS | None = None


class VLESSOutbound(BaseModel):
    type: str = "vless"
    tag: str
    server: str
    server_port: int = 443
    uuid: uuid.UUID
    flow: str = "xtls-rprx-vision"
    tls: TLS | None = None


class ExtraGroup(BaseModel):
    tag: str
    type: Literal["selector", "urltest"]
    outbounds: list[str] = []
    filter: re.Pattern[str] | None = None
    exclude: re.Pattern[str] | None = None


class SingBoxConfig(BaseModel):
    inbounds: list[VLESSInbound] | None = None
    outbounds: list[VLESSOutbound | ExtraGroup] | None = None


class GenerationConfig(BaseModel):
    extra_groups: list[ExtraGroup] = []


def urlsafe_b64encode_nopad(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def generate_sing_box_server_config(
    source: Source,
    server_name: str,
) -> SingBoxConfig:
    server = next(
        iter(server for server in source.servers if server.name == server_name)
    )
    return SingBoxConfig(
        inbounds=[
            VLESSInbound(
                users=[
                    VLESSUser(
                        name=user.display_name or user.name,
                        uuid=generate_user_uuid(
                            source.primary_key, server.name, user.name
                        ),
                    )
                    for user in source.users
                ],
                tls=TLS(
                    server_name=server.server or server.name,
                    reality=Reality(
                        handshake=Handshake(),
                        private_key=urlsafe_b64encode_nopad(
                            generate_server_private_key(source.primary_key, server.name)
                        ),
                        short_id=[
                            generate_short_id(
                                source.primary_key, server.name, user.name
                            )
                            for user in source.users
                        ],
                    ),
                ),
            )
        ]
    )


class VLESSXrayUser(BaseModel):
    id: uuid.UUID
    email: str
    flow: str = "xtls-rprx-vision"


class VLESSXrayInboundSettings(BaseModel):
    clients: list[VLESSXrayUser]
    decryption: str = "none"


class XRayRealitySettings(BaseModel):
    dest: str = "[::1]:40100"
    xver: int = 0
    serverNames: list[str]
    privateKey: str
    shortIds: list[str]


class XRaySteamSettings(BaseModel):
    network: str = "tcp"
    security: str = "reality"
    realitySettings: XRayRealitySettings


class VLESSXrayInbound(BaseModel):
    protocol: str = "vless"
    tag: str = "vless"
    listen: str = "::"
    port: int = 443
    settings: VLESSXrayInboundSettings
    streamSettings: XRaySteamSettings


class XRayConfig(BaseModel):
    inbounds: list[VLESSXrayInbound]


def generate_xray_server_config(
    source: Source,
    server_name: str,
) -> XRayConfig:
    server = next(
        iter(server for server in source.servers if server.name == server_name)
    )
    return XRayConfig(
        inbounds=[
            VLESSXrayInbound(
                settings=VLESSXrayInboundSettings(
                    clients=[
                        VLESSXrayUser(
                            id=generate_user_uuid(
                                source.primary_key, server.name, user.name
                            ),
                            email=user.display_name or user.name,
                        )
                        for user in source.users
                    ]
                ),
                streamSettings=XRaySteamSettings(
                    realitySettings=XRayRealitySettings(
                        serverNames=[server.server or server.name],
                        privateKey=urlsafe_b64encode_nopad(
                            generate_server_private_key(source.primary_key, server.name)
                        ),
                        shortIds=[
                            generate_short_id(
                                source.primary_key, server.name, user.name
                            )
                            for user in source.users
                        ],
                    )
                ),
            )
        ]
    )


def filter_items(
    items: list[str], filter: re.Pattern[str] | None, exclude: re.Pattern[str] | None
) -> list[str]:
    return [
        item
        for item in items
        if (filter is None or filter.match(item))
        and (exclude is None or not exclude.match(item))
    ]


def generate_client_config(
    source: Source,
    user_name: str,
    config: GenerationConfig,
) -> SingBoxConfig:
    _ = next(iter(user for user in source.users if user.name == user_name))
    server_outbounds = [
        server.display_name or server.server or server.name for server in source.servers
    ]
    extra_outbounds = [
        group.model_copy(
            update={
                "outbounds": group.outbounds
                + filter_items(server_outbounds, group.filter, group.exclude),
                "filter": None,
                "exclude": None,
            }
        )
        for group in config.extra_groups
    ]
    return SingBoxConfig(
        outbounds=extra_outbounds
        + [
            VLESSOutbound(
                tag=server.display_name or server.server or server.name,
                server=server.server or server.name,
                uuid=generate_user_uuid(source.primary_key, server.name, user_name),
                tls=TLS(
                    server_name=server.server or server.name,
                    utls=UTLS(),
                    reality=Reality(
                        public_key=urlsafe_b64encode_nopad(
                            generate_public_key(
                                generate_server_private_key(
                                    source.primary_key, server.name
                                )
                            )
                        ),
                        short_id=generate_short_id(
                            source.primary_key, server.name, user_name
                        ),
                    ),
                ),
            )
            for server in source.servers
        ]
    )


def write_reproducible_tarball(fp: BinaryIO, files: list[tuple[str, bytes]]) -> None:
    with GzipFile(filename="", fileobj=fp, mode="wb", mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode="w") as tar:
            for name, data in files:
                info = tarfile.TarInfo(name=name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))


def generate_subscription_files(source: Source) -> list[tuple[str, bytes]]:
    files: dict[str, bytes] = {}
    for user in source.users:
        # v2 subscription
        key = str(uuid.uuid5(source.namespace, user.name))
        files[f"v2/{key}"] = base64.b64encode(
            "".join(
                [
                    f"vless://{generate_user_uuid(source.primary_key, server.name, user.name)}@"
                    f"{server.server or server.name}:443?security=reality&encryption=none&"
                    f"pbk={urlsafe_b64encode_nopad(generate_public_key(generate_server_private_key(source.primary_key, server.name)))}&"
                    f"headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&"
                    f"sni={server.server or server.name}&"
                    f"sid={generate_short_id(source.primary_key, server.name, user.name)}"
                    f"#{quote_plus(server.display_name or server.server or server.name)}\n"
                    for server in source.servers
                ]
            ).encode()
        )
        files[f"clash/{key}"] = yaml.safe_dump(
            {
                "proxies": [
                    {
                        "name": server.display_name or server.server or server.name,
                        "type": "vless",
                        "server": server.server or server.name,
                        "port": 443,
                        "uuid": str(
                            generate_user_uuid(
                                source.primary_key, server.name, user.name
                            )
                        ),
                        "network": "tcp",
                        "tls": True,
                        "udp": True,
                        "flow": "xtls-rprx-vision",
                        "servername": server.server or server.name,
                        "reality-opts": {
                            "public-key": urlsafe_b64encode_nopad(
                                generate_public_key(
                                    generate_server_private_key(
                                        source.primary_key, server.name
                                    )
                                )
                            ),
                            "short-id": generate_short_id(
                                source.primary_key, server.name, user.name
                            ),
                        },
                        "client-fingerprint": "chrome",
                    }
                    for server in source.servers
                ]
            },
        ).encode()
    return [(k, files[k]) for k in sorted(files)]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--name",
        type=str,
        help="name of the server or client",
    )
    parser.add_argument(
        "--config",
        type=Path,
        help="path to the config file",
    )
    parser.add_argument(
        "--format",
        choices=["sing-box", "xray"],
        help="format of the config",
        default="sing-box",
    )
    parser.add_argument(
        "action",
        choices=["gen-primary-key", "gen-subscription", "gen-server", "gen-client"],
        help="mode of the operation",
    )
    parser.add_argument(
        "file",
        type=Path,
        help="path to the secret source file",
        nargs="?",
    )
    args = parser.parse_args()
    if args.action == "gen-primary-key":
        print(base64.b64encode(secrets.token_bytes(32)).decode())
        return
    source = Source.model_validate(
        yaml.safe_load(args.file.read_bytes() if args.file else sys.stdin.read())
    )
    match args.action:
        case "gen-subscription":
            write_reproducible_tarball(
                sys.stdout.buffer, generate_subscription_files(source)
            )
        case "gen-server":
            if args.name is None:
                raise ValueError("server name is required")
            match args.format:
                case "sing-box":
                    print(
                        generate_sing_box_server_config(
                            source, args.name
                        ).model_dump_json(exclude_none=True)
                    )
                case "xray":
                    print(
                        generate_xray_server_config(source, args.name).model_dump_json(
                            exclude_none=True
                        )
                    )
                case _:
                    raise ValueError(f"Invalid format: {args.format}")
        case "gen-client":
            if args.name is None:
                raise ValueError("user name is required")
            config = (
                GenerationConfig()
                if args.config is None
                else GenerationConfig.model_validate_json(args.config.read_bytes())
            )
            print(
                generate_client_config(source, args.name, config).model_dump_json(
                    exclude_none=True
                )
            )
        case _:
            raise ValueError(f"Invalid action: {args.action}")
