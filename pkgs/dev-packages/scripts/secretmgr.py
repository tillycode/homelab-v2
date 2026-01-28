import argparse
import json
import os
import sys
from abc import ABC, abstractmethod
from collections.abc import Generator
from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from pathlib import Path
from typing import Any, Final, Protocol

import yaml

from .utils import JSONValue, asyncio_run, get_root_directory, print_table, run

SECRETMGR_EVAL_SCRIPT_PATH = os.path.join(
    os.path.dirname(__file__), "secretmgr-eval.nix"
)

SOURCE_SECRET_PATH = "secrets/sources"
HOST_SECRET_PATH = "secrets/hosts"


@dataclass(frozen=True)
class HostSecretRequest:
    publicKey: str | None
    secrets: dict[str, set[str]]
    """filename -> set of keys"""

    @staticmethod
    def load_from_json(data: Any) -> dict[str, "HostSecretRequest"]:
        host_secret_requests: dict[str, HostSecretRequest] = {}
        for name, host in data.items():
            secrets: dict[str, set[str]] = {}
            secret: str
            for secret in host["secrets"]:
                filename, *rest = secret.split("/", maxsplit=1)
                key = rest[0] if rest else ""
                secrets.setdefault(filename, set()).add(key)
            host_secret_requests[name] = HostSecretRequest(
                publicKey=host["publicKey"],
                secrets=secrets,
            )
        return host_secret_requests


@dataclass(frozen=True)
class SourceSecrets:
    path: str
    lastModified: datetime
    secrets: set[str]
    """set of keys"""


@dataclass(frozen=True)
class HostSecrets:
    path: str
    lastModified: datetime
    publicKey: str | None
    secrets: set[str]


async def get_host_secret_requests(
    root: Path,
    host_secret_requests_path: Path | None = None,
) -> dict[str, HostSecretRequest]:
    if host_secret_requests_path is not None:
        with open(host_secret_requests_path, "r") as f:
            return HostSecretRequest.load_from_json(json.load(f))
    output = await run(
        "nix-instantiate",
        "--json",
        "--eval",
        "--strict",
        SECRETMGR_EVAL_SCRIPT_PATH,
        "--quiet",
        "--argstr",
        "importPath",
        str(root),
    )
    return HostSecretRequest.load_from_json(json.loads(output))


def traverse_secret_tree(
    dest: set[str],
    data: dict[str, JSONValue],
    prefix: str = "",
) -> None:
    for key, value in data.items():
        if isinstance(value, dict):
            traverse_secret_tree(dest, value, f"{prefix}{key}/")
        else:
            dest.add(f"{prefix}{key}")


def get_age_public_key(sops: JSONValue) -> str | None:
    assert isinstance(sops, dict)
    age = sops.get("age", [])
    assert isinstance(age, list)
    if not len(age) == 1:
        return None
    age_item = age[0]
    assert isinstance(age_item, dict)
    recipient = age_item.get("recipient")
    assert recipient is None or isinstance(recipient, str)
    return recipient


def get_last_modified(sops: JSONValue) -> datetime:
    assert isinstance(sops, dict)
    lastmodified = sops.get("lastmodified")
    assert isinstance(lastmodified, str)
    return datetime.fromisoformat(lastmodified)


def get_source_secrets(
    root: Path,
) -> dict[str, SourceSecrets]:
    source_secrets: dict[str, SourceSecrets] = {}
    for entry in os.scandir(root / SOURCE_SECRET_PATH):
        if not entry.is_file():
            continue
        name, ext = os.path.splitext(entry.name)
        if ext not in (".yaml", ".yml"):
            continue
        with open(entry.path, "r") as f:
            data: dict[str, JSONValue] = yaml.load(f, Loader=yaml.CLoader)
        sops = data.pop("sops")
        secrets = set[str]()
        traverse_secret_tree(secrets, data)
        source_secrets[name] = SourceSecrets(
            path=entry.path,
            lastModified=get_last_modified(sops),
            secrets=secrets,
        )
    return source_secrets


def get_host_secrets(
    root: Path,
) -> dict[str, HostSecrets]:
    host_secrets: dict[str, HostSecrets] = {}
    for entry in os.scandir(root / HOST_SECRET_PATH):
        if not entry.is_file():
            continue
        name, ext = os.path.splitext(entry.name)
        if ext not in (".yaml", ".yml"):
            continue
        with open(entry.path, "r") as f:
            data: dict[str, JSONValue] = yaml.load(f, Loader=yaml.CLoader)
        sops = data.pop("sops")
        secrets = set[str]()
        traverse_secret_tree(secrets, data)
        host_secrets[name] = HostSecrets(
            path=entry.path,
            lastModified=get_last_modified(sops),
            publicKey=get_age_public_key(sops),
            secrets=secrets,
        )
    return host_secrets


def is_feasible(
    host_secret_request: HostSecretRequest,
    source_secrets: dict[str, SourceSecrets],
) -> tuple[str, bool]:
    if host_secret_request.secrets and not host_secret_request.publicKey:
        return "missing public key", False
    for filename, keys in host_secret_request.secrets.items():
        source_secret = source_secrets.get(filename)
        if source_secret is None:
            return f"missing source secret {filename}.yaml", False
        missing_keys = keys - source_secret.secrets
        if missing_keys:
            reason = f"missing secret {filename}/{next(iter(missing_keys))}"
            if len(missing_keys) > 1:
                reason += " ..."
            return reason, False
    return "", True


def is_outdated(
    host_secret_request: HostSecretRequest,
    host_secret: HostSecrets | None,
    source_secrets: dict[str, SourceSecrets],
) -> tuple[str, bool]:
    if not host_secret_request.secrets and host_secret is None:
        return "no secrets", False
    if host_secret is None:
        return "missing generated secret file", True
    if not host_secret_request.secrets:
        return "no secrets", True
    if host_secret.publicKey != host_secret_request.publicKey:
        return "public key changed", True
    host_requested_secrets = {
        f"{filename}/{key}"
        for filename, keys in host_secret_request.secrets.items()
        for key in keys
    }
    if host_secret.secrets != host_requested_secrets:
        if added := host_requested_secrets - host_secret.secrets:
            reason = f"added secret {next(iter(added))}"
            if len(added) > 1:
                reason += " ..."
        else:
            removed = host_secret.secrets - host_requested_secrets
            reason = f"removed secret {next(iter(removed))}"
            if len(removed) > 1:
                reason += " ..."
        return reason, True
    for filename in host_secret_request.secrets:
        source_secret = source_secrets.get(filename)
        if (
            source_secret is None
            or source_secret.lastModified >= host_secret.lastModified
        ):
            return "source secret modified", True
    return "up to date", False


class EvaluationStatus(StrEnum):
    SYNCED = ""  # nf-fa-check
    OUTDATED = ""  # nf-fa-xmark
    ERROR = ""  # nf-fa-exclamation


@dataclass(frozen=True)
class EvaluationResult:
    host: str
    status: EvaluationStatus
    reason: str


class Action(Protocol):
    evaluation_result: Final[EvaluationResult | None]

    async def execute(self, context: dict[str, JSONValue], dry_run: bool) -> None: ...


class BaseAction(ABC):
    async def execute(self, context: dict[str, JSONValue], dry_run: bool) -> None:
        print(f"{self} ... ".ljust(40), end="", flush=True)
        if not dry_run:
            await self.do(context)
            print("DONE")
        else:
            print("DONE (dry run)")

    @abstractmethod
    async def do(self, context: dict[str, JSONValue]) -> None:
        raise NotImplementedError


class DecryptAction(BaseAction):
    evaluation_result: None
    name: str
    path: str

    def __init__(self, name: str, path: str) -> None:
        self.evaluation_result = None
        self.name = name
        self.path = path

    def __str__(self) -> str:
        return f"Decrypting {os.path.basename(self.path)}"

    async def do(self, context: dict[str, JSONValue]) -> None:
        output = await run(
            "sops",
            "decrypt",
            "--output-type",
            "json",
            self.path,
        )
        data: JSONValue = json.loads(output)
        context[self.name] = data


class EncryptAction(BaseAction):
    evaluation_result: EvaluationResult
    path: str
    host_secret_request: HostSecretRequest

    def __init__(
        self,
        evaluation_result: EvaluationResult,
        path: str,
        host_secret_request: HostSecretRequest,
    ) -> None:
        self.evaluation_result = evaluation_result
        self.path = path
        self.host_secret_request = host_secret_request

    def __str__(self) -> str:
        return f"Encrypting {os.path.basename(self.path)}"

    # well, make pyright happy
    @staticmethod
    def get_src_node(src: JSONValue, component: str) -> JSONValue:
        assert isinstance(src, dict)
        return src.get(component)

    @staticmethod
    def get_dest_node(dest: JSONValue, component: str, src: JSONValue) -> JSONValue:
        assert isinstance(dest, dict)
        if isinstance(src, dict):
            return dest.setdefault(component, {})
        return dest.setdefault(component, src)

    @staticmethod
    def collect_secrets(dest: JSONValue, src: JSONValue, path: list[str]) -> None:
        for component in path:
            src = EncryptAction.get_src_node(src, component)
            dest = EncryptAction.get_dest_node(dest, component, src)

    async def do(self, context: dict[str, JSONValue]) -> None:
        secrets: JSONValue = {}
        for filename, keys in self.host_secret_request.secrets.items():
            for key in keys:
                self.collect_secrets(secrets, context, [filename] + key.split("/"))

        assert self.host_secret_request.publicKey is not None
        await run(
            "sops",
            "encrypt",
            "--input-type",
            "json",
            "--output",
            self.path,
            "--filename-override",
            self.path,
            "--age",
            self.host_secret_request.publicKey,
            input=json.dumps(secrets).encode(),
            env={"PATH": os.environ["PATH"], "SOPS_CONFIG": "/dev/null"},
        )


class DeleteAction(BaseAction):
    evaluation_result: EvaluationResult
    path: str

    def __init__(self, evaluation_result: EvaluationResult, path: str) -> None:
        self.evaluation_result = evaluation_result
        self.path = path

    def __str__(self) -> str:
        return f"Deleting {os.path.basename(self.path)}"

    async def do(self, context: JSONValue) -> None:
        os.remove(self.path)


class EvaluationResultAction:
    evaluation_result: EvaluationResult
    message: str | None

    def __init__(
        self, evaluation_result: EvaluationResult, message: str | None = None
    ) -> None:
        self.evaluation_result = evaluation_result
        self.message = message

    async def execute(self, context: JSONValue, dry_run: bool) -> None:
        if self.message is not None:
            print(self.message, file=sys.stderr)
            raise SystemExit(1)


def plan_sync_secrets(
    host_secret_requests: dict[str, HostSecretRequest],
    source_secrets: dict[str, SourceSecrets],
    host_secrets: dict[str, HostSecrets],
    root: Path,
) -> Generator[Action, None, None]:
    sources_to_decrypt: set[str] = set()
    hosts_to_encrypt: dict[str, str] = {}
    hosts_to_delete: dict[str, str] = {}
    for host, host_secret_request in host_secret_requests.items():
        host_secret = host_secrets.get(host)
        reason, feasible = is_feasible(host_secret_request, source_secrets)
        if not feasible:
            yield EvaluationResultAction(
                EvaluationResult(host, EvaluationStatus.ERROR, reason),
                f"ERROR: host {host} {reason}",
            )
            continue
        reason, outdated = is_outdated(host_secret_request, host_secret, source_secrets)
        if not outdated:
            yield EvaluationResultAction(
                EvaluationResult(host, EvaluationStatus.SYNCED, reason)
            )
            continue
        if host_secret_request.secrets:
            sources_to_decrypt.update(host_secret_request.secrets)
            hosts_to_encrypt[host] = reason
        else:
            hosts_to_delete[host] = reason
    for host, host_secret in host_secrets.items():
        if host not in host_secret_requests:
            hosts_to_delete[host] = "host disappeared"
    for source in sources_to_decrypt:
        yield DecryptAction(source, source_secrets[source].path)
    for host, reason in hosts_to_encrypt.items():
        if host_secret := host_secrets.get(host):
            path = host_secret.path
        else:
            path = str(root / HOST_SECRET_PATH / f"{host}.yaml")
        host_secret_request = host_secret_requests[host]
        assert host_secret_request.publicKey is not None
        yield EncryptAction(
            EvaluationResult(host, EvaluationStatus.OUTDATED, reason),
            path,
            host_secret_request,
        )
    for host, reason in hosts_to_delete.items():
        yield DeleteAction(
            EvaluationResult(host, EvaluationStatus.OUTDATED, reason),
            host_secrets[host].path,
        )


async def apply_secrets(
    dry_run: bool = False,
    host_secret_requests_path: Path | None = None,
) -> None:
    root = get_root_directory()
    host_secret_requests = await get_host_secret_requests(
        root,
        host_secret_requests_path,
    )
    source_secrets = get_source_secrets(root)
    # filter out hosts which doesn't request any secrets
    host_secrets = get_host_secrets(root)
    # compute actions to be done
    context: JSONValue = {}
    for action in plan_sync_secrets(
        host_secret_requests, source_secrets, host_secrets, root
    ):
        await action.execute(context, dry_run)


async def status_secrets(
    check: bool = False,
    host_secret_requests_path: Path | None = None,
) -> None:
    root = get_root_directory()
    host_secret_requests = await get_host_secret_requests(
        root,
        host_secret_requests_path,
    )
    source_secrets = get_source_secrets(root)
    host_secrets = get_host_secrets(root)

    evaluation_results: dict[str, EvaluationResult] = {}
    out_of_sync = False
    for action in plan_sync_secrets(
        host_secret_requests, source_secrets, host_secrets, root
    ):
        if action.evaluation_result is not None:
            evaluation_results[action.evaluation_result.host] = action.evaluation_result
        if (
            action.evaluation_result is None
            or action.evaluation_result.status != EvaluationStatus.SYNCED
        ):
            out_of_sync = True

    rows: list[list[str]] = [["HOST", "SYNCED", "REASON"]]
    for host in sorted(evaluation_results):
        evaluation_result = evaluation_results[host]
        rows.append([host, evaluation_result.status.value, evaluation_result.reason])
    print_table(rows)
    if check and out_of_sync:
        raise SystemExit(2)


@asyncio_run
async def main() -> None:
    secret_parent_parser = argparse.ArgumentParser(add_help=False)
    secret_parent_parser.add_argument(
        "--host-secret-requests-path",
        type=Path,
        help="path to the host secret requests evaluation result",
    )
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(
        dest="subcommand",
        required=True,
    )
    parser_apply = subparsers.add_parser(
        "apply",
        parents=[secret_parent_parser],
        help="sync secrets from source to nodes",
    )
    parser_apply.add_argument(
        "--dry-run",
        action="store_true",
        help="dry run",
    )
    parser_status = subparsers.add_parser(
        "status",
        parents=[secret_parent_parser],
        help="show status of secrets",
    )
    parser_status.add_argument(
        "--check",
        action="store_true",
        help="check if secrets are in sync",
    )
    args = parser.parse_args()
    match args.subcommand:  # pyright: ignore[reportMatchNotExhaustive]
        case "apply":
            await apply_secrets(
                dry_run=args.dry_run,
                host_secret_requests_path=args.host_secret_requests_path,
            )
        case "status":
            await status_secrets(
                check=args.check,
                host_secret_requests_path=args.host_secret_requests_path,
            )
