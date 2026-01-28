import argparse
import json
import sys
from dataclasses import dataclass, field


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


@dataclass(frozen=True)
class CheckFlatFlake:
    nodes: dict[str, Node]
    paths: list[str] = field(default_factory=list[str], init=False)
    violations: list[list[str]] = field(default_factory=list[list[str]], init=False)

    def check(self, current: str, depth: int = 0) -> None:
        node = self.nodes[current]
        for name, value in node.inputs.items():
            self.paths.append(name)
            # we only care about new dependencies
            if isinstance(value, str):
                if depth > 0:
                    self.violations.append(self.paths.copy())
                else:
                    self.check(value, depth + 1)
            self.paths.pop()


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
        check = CheckFlatFlake(nodes=lock.nodes)
        check.check(lock.root)
        if len(check.violations) > 0:
            print(f"found violations in {file}", file=sys.stderr)
            for violation in check.violations:
                print(f"  {'/'.join(violation)}", file=sys.stderr)
            sys.exit(1)
    print("no violations found", file=sys.stderr)


if __name__ == "__main__":
    main()
