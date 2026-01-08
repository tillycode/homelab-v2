#!/usr/bin/env python3

import argparse
import asyncio
import contextlib
import json
import os
import subprocess
import sys
import tempfile
from collections.abc import AsyncGenerator
from dataclasses import dataclass
from pathlib import Path

PACKAGE_EVAL_SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "eval.nix")


def search_upwards_for_file(directory: Path, filename: str) -> Path | None:
    root = Path(directory.root)
    while directory != root:
        attempt = directory / filename
        if attempt.exists():
            return directory
        directory = directory.parent
    return None


async def run(
    *args: str,
    cwd: str | None = None,
    env: dict[str, str] | None = None,
    input: bytes | None = None,
    stdout: int | None = asyncio.subprocess.PIPE,
    stderr: int | None = None,
) -> bytes:
    process = await asyncio.create_subprocess_exec(
        *args,
        cwd=cwd,
        env=env,
        stdout=stdout,
        stderr=stderr,
    )
    output, error = await process.communicate(input)
    if process.returncode is not None and process.returncode != 0:
        raise subprocess.CalledProcessError(process.returncode, args, output, error)

    return output or b""


async def get_nixpks_path(
    flake_path: str,
) -> str:
    output = await run(
        "nix-instantiate",
        "--eval",
        "--raw",
        "--expr",
        "{ importPath }: (builtins.getFlake importPath).inputs.nixpkgs.outPath",
        "--argstr",
        "importPath",
        flake_path,
    )
    return output.decode().strip()


@dataclass(frozen=True)
class PackageData:
    attrPath: list[str]
    name: str
    pname: str
    version: str
    updateScript: list[str] | None
    supportedFeatures: list[str]


async def load_package_data(
    package_path: str,
) -> list[PackageData]:
    output = await run(
        "nix-instantiate",
        "--eval",
        "--json",
        "--strict",
        PACKAGE_EVAL_SCRIPT_PATH,
        "--argstr",
        "importPath",
        package_path,
    )
    data = json.loads(output)
    return [PackageData(**item) for item in data]


@contextlib.asynccontextmanager
async def make_worktree() -> AsyncGenerator[tuple[str, str], None]:
    with tempfile.TemporaryDirectory() as wt:
        branch_name = f"update-{os.path.basename(wt)}"
        target_directory = f"{wt}/flake"

        await run("git", "worktree", "add", "-q", "-b", branch_name, target_directory)
        try:
            yield (target_directory, branch_name)
        finally:
            await run("git", "worktree", "remove", "--force", target_directory)
            await run("git", "branch", "-D", branch_name)


def get_root_directory() -> Path:
    root = search_upwards_for_file(Path.cwd(), "flake.nix")
    if root is None:
        raise FileNotFoundError("flake.nix not found")
    return root


class AsyncQueueIterator[T]:
    queue: asyncio.Queue[T]

    def __init__(self, queue: asyncio.Queue[T]):
        self.queue = queue

    def __aiter__(self) -> "AsyncQueueIterator[T]":
        return self

    async def __anext__(self) -> T:
        try:
            return await self.queue.get()
        except asyncio.QueueShutDown:
            raise StopAsyncIteration


async def update_worker(
    queue: asyncio.Queue[PackageData],
    root: Path,
    temp_dir: tuple[str, str] | None,
) -> None:
    async for package in AsyncQueueIterator(queue):
        if package.updateScript is None:
            print(f" - {package.name}: SKIPPED (no update script)")
            continue
        print(f" - {package.name}: UPDATING ...")
        worktree = str(root)
        branch: str | None = None
        if temp_dir is not None:
            worktree, branch = temp_dir
        try:
            update_output = await run(
                *package.updateScript,
                stderr=asyncio.subprocess.PIPE,
                env={
                    **os.environ,
                    "UPDATE_NIX_NAME": package.name,
                    "UPDATE_NIX_PNAME": package.pname,
                    "UPDATE_NIX_OLD_VERSION": package.version,
                    # maybe we need to escape the dots?
                    "UPDATE_NIX_ATTR_PATH": ".".join(package.attrPath),
                },
                cwd=worktree,
            )
            if branch is None:
                print(f" - {package.name}: DONE")
                continue
            print(update_output.decode("utf-8"))
            print(f" - {package.name}: CHECKING OUT {branch}")
        except subprocess.CalledProcessError as e:
            print(f" - {package.name}: ERROR: {e}")
            if e.stderr is not None:
                print(f"--- BEGIN ERROR LOG FOR {package.name} ----------------------")
                print()
                print(e.stderr.decode("utf-8"))
                with open(f"{package.pname}.log", "wb") as logfile:
                    logfile.write(e.stderr)
                print()
                print(f"--- END ERROR LOG FOR {package.name} -------------------------")


async def update(
    max_workers: int,
    keep_going: bool,
    commit: bool,
) -> None:
    # TODO: warn if dirty
    root = get_root_directory()
    os.environ["NIX_PATH"] = f"nixpkgs={await get_nixpks_path(str(root))}"
    packages = await load_package_data(str(root / "pkgs"))
    num_workers = min(max_workers, len(packages))
    queue: asyncio.Queue[PackageData] = asyncio.Queue()

    async with contextlib.AsyncExitStack() as stack:
        temp_dirs: list[tuple[str, str] | None] = [None] * num_workers
        for i in range(num_workers):
            if commit:
                temp_dir = await stack.enter_async_context(make_worktree())
                print(f" - Create worktree: {temp_dir[0]}")
                temp_dirs[i] = temp_dir

        tg = await stack.enter_async_context(asyncio.TaskGroup())
        for i in range(num_workers):
            tg.create_task(
                update_worker(
                    queue=queue,
                    root=root,
                    temp_dir=temp_dirs[i],
                )
            )

        for package in packages:
            await queue.put(package)
        queue.shutdown()


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(
        dest="subcommand",
        required=True,
    )
    parser_update = subparsers.add_parser("update", help="update packages")
    parser_update.add_argument(
        "-j",
        "--max-workers",
        type=int,
        default=4,
        help="maximum number of workers to use",
    )
    parser_update.add_argument(
        "-k",
        "--keep-going",
        action="store_true",
        help="continue updating packages even if some packages fail",
    )
    parser_update.add_argument(
        "--commit",
        "-c",
        dest="commit",
        action="store_true",
        help="commit the changes",
    )
    args = parser.parse_args()
    match args.subcommand:  # pyright: ignore[reportMatchNotExhaustive]
        case "update":
            try:
                asyncio.run(
                    update(
                        max_workers=args.max_workers,
                        keep_going=args.keep_going,
                        commit=args.commit,
                    )
                )
            except KeyboardInterrupt:
                sys.exit(130)


if __name__ == "__main__":
    main()
