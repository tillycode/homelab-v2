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
from typing import Any

from .utils import (
    AsyncQueueIterator,
    asyncio_run,
    escape_nix_string,
    get_root_directory,
    lock_file,
    print_table,
    run,
)

PACKAGE_EVAL_SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "pkgmgr-eval.nix")


@dataclass(frozen=True)
class PackageData:
    attrPath: list[str]
    name: str
    pname: str
    version: str
    updateScript: list[str] | None
    supportedFeatures: list[str]


@dataclass(frozen=True)
class EvaluationResult:
    nixpkgs: str
    packages: list[PackageData]


@dataclass(frozen=True)
class CommitChange:
    attrPath: str
    oldVersion: str
    newVersion: str
    files: list[str]
    commitMessage: str | None = None
    commitBody: str | None = None


async def evaluation(
    import_path: str,
    out_link: str | None = None,
    root: str | None = None,
    predicate: str | None = None,
    attrPaths: list[str] | None = None,
) -> EvaluationResult:
    args: list[str] = [
        "--argstr",
        "importPath",
        import_path,
    ]
    if root is not None:
        args += [
            "--arg",
            "pkgs",
            f"import ((builtins.getFlake {escape_nix_string(str(root))}).inputs.nixpkgs) {{}}",
        ]
    if predicate is not None:
        args += ["--arg", "predicate", predicate]
    if attrPaths is not None:
        args += ["--argstr", "attrPathsJSON", json.dumps(attrPaths)]
    if out_link is not None:
        await run(
            "nix-build",
            PACKAGE_EVAL_SCRIPT_PATH,
            "--quiet",
            "--out-link",
            out_link,
            *args,
        )
        with open(out_link) as f:
            data = json.load(f)
    else:
        output = await run(
            "nix-instantiate",
            "--json",
            "--eval",
            "--strict",
            PACKAGE_EVAL_SCRIPT_PATH,
            "--quiet",
            "--arg",
            "eval",
            "true",
            *args,
        )
        data = json.loads(output)
    return EvaluationResult(
        nixpkgs=data["nixpkgs"],
        packages=[PackageData(**item) for item in data["packages"]],
    )


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


async def check_changes(
    package: PackageData,
    worktree: str,
    update_info: bytes,
    import_path: str,
) -> list[CommitChange]:
    if "commit" in package.supportedFeatures:
        changes: Any = json.loads(update_info)
    else:
        changes = [{}]
    if len(changes) == 1:
        change = changes[0]
        if change.get("attrPath") is None:
            change["attrPath"] = ".".join(package.attrPath)
        if change.get("oldVersion") is None:
            change["oldVersion"] = package.version
        if change.get("newVersion") is None:
            new_version_output = await run(
                "nix-instantiate",
                "--raw",
                "--eval",
                "--expr",
                r"""{
  importPath,
  attrPathJSON,
  pkgs ? import <nixpkgs> { },
}:
let
  getAttrFromPath =
    attrPath: set:
    let
      lenAttrPath = builtins.length attrPath;
      getAttrFromPath' =
        n: s: if n == lenAttrPath then s else getAttrFromPath' (n + 1) (s.${builtins.elemAt attrPath n});
    in
    getAttrFromPath' 0 set;
  getVersion = drv: drv.version or (builtins.parseDrvName drv.name).version;
  attrPath = builtins.fromJSON attrPathJSON;
  packages = import importPath { inherit pkgs; };
in
getVersion (getAttrFromPath attrPath packages)
""",
                "--argstr",
                "importPath",
                import_path,
                "--argstr",
                "attrPathJSON",
                json.dumps(package.attrPath),
            )
            change["newVersion"] = new_version_output.decode().strip()
        if change.get("files") is None:
            changed_files_output = await run(
                "git",
                "diff",
                "--name-only",
                "HEAD",
                cwd=worktree,
            )
            change["files"] = changed_files_output.decode().splitlines()
        if not change["files"]:
            return []
    return [CommitChange(**change) for change in changes]


async def commit_changes(
    merge_lock: asyncio.Lock,
    changes: list[CommitChange],
    worktree: str,
    branch: str,
) -> None:
    for change in changes:
        await run("git", "add", *change.files, cwd=worktree)
        commit_message = (
            change.commitMessage
            or f"{change.attrPath}: {change.oldVersion} -> {change.newVersion}"
        )
        if change.commitBody is not None:
            commit_message += f"\n\n{change.commitBody}"
        await run("git", "commit", "--quiet", "-m", commit_message, cwd=worktree)
        async with merge_lock:
            await run("git", "cherry-pick", branch)


async def update_worker(
    queue: asyncio.Queue[PackageData],
    merge_lock: asyncio.Lock,
    root: str,
    temp_dir: tuple[str, str] | None,
    keep_going: bool,
) -> None:
    async for package in AsyncQueueIterator(queue):
        assert package.updateScript is not None
        print(f" - {package.name}: UPDATING ...")
        worktree = str(root)
        branch: str | None = None
        args = package.updateScript
        if temp_dir is not None:
            worktree, branch = temp_dir
            await run("git", "reset", "--hard", "--quiet", "HEAD", cwd=worktree)
            args = args[:]
            for i, arg in enumerate(args):
                if arg.startswith(root) and (
                    len(arg) == len(root) or arg[len(root)] == os.path.sep
                ):
                    args[i] = worktree + arg[len(root) :]
        try:
            update_output = await run(
                *args,
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
            changes = await check_changes(
                package,
                worktree,
                update_output,
                os.path.join(worktree, "pkgs"),
            )
            if changes:
                await commit_changes(merge_lock, changes, worktree, branch)
                print(f" - {package.name}: DONE (updated)")
            else:
                print(f" - {package.name}: DONE (no changes)")
        except subprocess.CalledProcessError as e:
            print(f" - {package.name}: ERROR: {e}")
            if e.stderr is not None:
                print(f"--- BEGIN ERROR LOG FOR {package.name} ----------------------")
                print(e.stderr.decode("utf-8").rstrip("\n"))
                print(f"--- END ERROR LOG FOR {package.name} -------------------------")
            if not keep_going:
                raise


async def update(
    max_workers: int,
    keep_going: bool,
    commit: bool,
    predicate: str | None,
    attrPaths: list[str] | None,
) -> None:
    root = get_root_directory()
    state_dir = root / ".data" / "pkgmgr"
    os.makedirs(state_dir, exist_ok=True)
    async with contextlib.AsyncExitStack() as stack:
        if commit:
            try:
                await run("git", "diff", "--quiet", "HEAD")
            except subprocess.CalledProcessError as e:
                if e.returncode == 1:
                    print(
                        "ERROR: commit your changes or stash them first",
                        file=sys.stderr,
                    )
                    sys.exit(1)
                raise

        # evaluation
        stack.enter_context(lock_file(state_dir / "lock"))
        out_link_path = state_dir / "eval.json"
        import_path = root / "pkgs"
        evaluation_result = await evaluation(
            import_path=str(import_path),
            out_link=str(out_link_path),
            root=str(root),
            predicate=predicate,
            attrPaths=attrPaths,
        )
        stack.callback(lambda: out_link_path.unlink(missing_ok=True))

        os.environ["NIX_PATH"] = f"nixpkgs={evaluation_result.nixpkgs}"
        packages: list[PackageData] = []
        for package in evaluation_result.packages:
            if not package.updateScript:
                print(f" - {package.name}: SKIPPED (no update script)")
                continue
            packages.append(package)
        num_workers = min(max_workers, len(packages))
        queue: asyncio.Queue[PackageData] = asyncio.Queue()
        merge_lock: asyncio.Lock = asyncio.Lock()

        temp_dirs: list[tuple[str, str] | None] = [None] * num_workers
        if commit:
            for i in range(num_workers):
                temp_dirs[i] = await stack.enter_async_context(make_worktree())

        tg = await stack.enter_async_context(asyncio.TaskGroup())
        for i in range(num_workers):
            tg.create_task(
                update_worker(
                    queue=queue,
                    merge_lock=merge_lock,
                    root=str(root),
                    temp_dir=temp_dirs[i],
                    keep_going=keep_going,
                )
            )

        for package in packages:
            await queue.put(package)
        queue.shutdown()


async def list_packages() -> None:
    root = get_root_directory()
    evaluation_result = await evaluation(
        import_path=str(root / "pkgs"),
        root=str(root),
    )
    rows: list[list[str]] = [["PACKAGE", "NAME", "VERSION", "HAS UPDATE SCRIPT"]]
    for package in evaluation_result.packages:
        rows.append(
            [
                ".".join(package.attrPath),
                package.pname,
                package.version,
                "" if package.updateScript else "",  # nf-fa-check and nf-fa-xmark
            ]
        )
    print_table(rows)


@asyncio_run
async def main() -> None:
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
    parser_update.add_argument(
        "--predicate",
        "-p",
        help="predicate to filter packages",
        default=None,
        type=str,
    )
    parser_update.add_argument(
        "package",
        nargs="*",
        help="packages to update",
        default=None,
    )
    subparsers.add_parser("list", help="list packages")
    args = parser.parse_args()
    match args.subcommand:  # pyright: ignore[reportMatchNotExhaustive]
        case "update":
            try:
                await update(
                    max_workers=args.max_workers,
                    keep_going=args.keep_going,
                    commit=args.commit,
                    predicate=args.predicate,
                    attrPaths=args.package or None,
                )
            except KeyboardInterrupt:
                sys.exit(130)
        case "list":
            await list_packages()
