import argparse
import json
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Node:
    # If the value is a string, it introduce a new dependency.
    # If the value is a list of strings, it follows an existing dependency.
    # In a flat flake, all other nodes except the root must NOT introduce new dependencies.
    inputs: dict[str, str | list[str]]


@dataclass(frozen=True)
class Lock:
    root: str
    nodes: dict[str, Node]


def load_lock(path: str) -> Lock:
    with open(path) as f:
        content = json.load(f)
    return Lock(
        root=content["root"],
        nodes={
            name: Node(inputs=node.get("inputs", {}))
            for name, node in content.get("nodes", {}).items()
        },
    )


def check_flat_flake(lock: Lock) -> dict[str, list[list[str]]]:
    definitions = dict[str, list[list[str]]]()
    paths = list[str]()

    def traverse(current: str) -> None:
        node = lock.nodes[current]
        for name, value in node.inputs.items():
            paths.append(name)
            # we only care about new dependencies
            if isinstance(value, str):
                definitions.setdefault(name, []).append(paths[:])
                traverse(value)
            paths.pop()

    traverse(lock.root)
    print(definitions)

    return {k: v for k, v in definitions.items() if len(v) > 1}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "file",
        help="path to the flake lock file",
        nargs="+",
    )

    args = parser.parse_args()
    for file in args.file:
        lock = load_lock(file)
        violations = check_flat_flake(lock)
        if violations:
            print(f"found {len(violations)} violation(s) in {file}", file=sys.stderr)
            for key, paths in violations.items():
                print(
                    f"  {key}: {', '.join('/'.join(path) for path in paths)}",
                    file=sys.stderr,
                )
            sys.exit(1)
    print("no violations found", file=sys.stderr)


if __name__ == "__main__":
    main()
