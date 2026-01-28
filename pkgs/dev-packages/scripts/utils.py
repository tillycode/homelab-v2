import asyncio
import contextlib
import errno
import json
import os
import subprocess
from collections.abc import Callable, Coroutine, Generator
from itertools import zip_longest
from pathlib import Path
from typing import Any

type JSONValue = (
    dict[str, JSONValue] | list[JSONValue] | str | int | float | bool | None
)


def search_upwards_for_file(directory: Path, filename: str) -> Path | None:
    root = Path(directory.root)
    while directory != root:
        attempt = directory / filename
        if attempt.exists():
            return directory
        directory = directory.parent
    return None


def get_root_directory() -> Path:
    root = search_upwards_for_file(Path.cwd(), "flake.nix")
    if root is None:
        raise FileNotFoundError("flake.nix not found")
    return root


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
        stdin=None if input is None else asyncio.subprocess.PIPE,
        stdout=stdout,
        stderr=stderr,
    )
    output, error = await process.communicate(input)
    if process.returncode is not None and process.returncode != 0:
        raise subprocess.CalledProcessError(
            process.returncode,
            list(args),
            output,
            error,
        )

    return output or b""


def escape_nix_string(s: str) -> str:
    """similar to lib.strings.escapeNixString"""
    return json.dumps(s).replace("$", "\\$")


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


@contextlib.contextmanager
def lock_file(path: Path) -> Generator[None, None, None]:
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, mode=0o644)
        os.close(fd)
    except OSError as e:
        if e.errno == errno.EEXIST:
            raise FileExistsError(f"Lock file already exists: {path}")
        raise
    try:
        yield
    finally:
        path.unlink(missing_ok=True)


def asyncio_run[T](func: Callable[[], Coroutine[Any, Any, T]]) -> Callable[[], T]:
    return lambda: asyncio.run(func())


def print_table(rows: list[list[str]]) -> None:
    widths = [
        max(len(cell) for cell in column) for column in zip_longest(*rows, fillvalue="")
    ]
    sep = " " * 3
    for row in rows:
        for i, (cell, width) in enumerate(zip(row, widths)):
            if i != len(row) - 1:
                print(cell.ljust(width), end=sep)
                continue
            print(cell)
