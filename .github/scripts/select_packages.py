#!/usr/bin/env python3
"""Decide which Julia packages a change set affects.

The dependency graph is read from the Project.toml files themselves rather than
hardcoded, so the fan-out cannot drift when a dependency is added or dropped.
A change to Julia/KhepriBase must rebuild everything, and that falls out of the
reverse-transitive closure instead of being asserted.

Emits `key=value` lines in $GITHUB_OUTPUT format on stdout. Values are compact
JSON arrays: $GITHUB_OUTPUT is line-oriented, so they must not be pretty-printed.

Usage, from the repository root:
    select_packages.py --all
    select_packages.py --tag KhepriBase-v0.8.1
    git diff --name-only A B | select_packages.py --changed
"""

import json
import sys
import tomllib
from pathlib import Path

ROOT = Path("Julia")

# Packages that exist in the General registry. Only these can have all their
# dependencies resolved from the registry, so only these can be checked for the
# version-skew class of bug the `registry-deps` job exists to catch. Verified
# against the local General registry clone on 2026-08-03; extend as more are
# registered.
REGISTERED = {"Khepri", "KhepriAutoCAD", "KhepriBase", "KhepriIllustrator", "KhepriTikZ"}

# KhepriFrame4DD's docs environment depends on KhepriThebes, which is neither in
# this repository nor in the General registry, so Pkg.instantiate() for it cannot
# succeed. Excluded from docs builds until that is resolved -- a knowingly-failing
# job trains people to ignore red.
DOCS_EXCLUDED = {"KhepriFrame4DD": "docs/Project.toml requires KhepriThebes, which is unregistered"}


def packages():
    return sorted(p.parent.name for p in ROOT.glob("*/Project.toml"))


def dependency_graph(names):
    known, graph = set(names), {}
    for name in names:
        with open(ROOT / name / "Project.toml", "rb") as fh:
            project = tomllib.load(fh)
        graph[name] = {d for d in project.get("deps", {}) if d in known}
    return graph


def dependents_of(graph):
    """For each package, itself plus everything that transitively depends on it."""
    reverse = {n: set() for n in graph}
    for name, deps in graph.items():
        for dep in deps:
            reverse[dep].add(name)
    closure = {}
    for name in graph:
        seen, todo = set(), [name]
        while todo:
            current = todo.pop()
            if current in seen:
                continue
            seen.add(current)
            todo.extend(reverse[current])
        closure[name] = seen
    return closure


def affected(changed_paths, names):
    closure = dependents_of(dependency_graph(names))
    selected = set()
    for path in changed_paths:
        parts = Path(path).parts
        # Anything shared -- the workflows, the helper scripts -- rebuilds all.
        if parts and parts[0] == ".github":
            return set(names)
        if len(parts) >= 2 and parts[0] == "Julia" and parts[1] in closure:
            selected |= closure[parts[1]]
    return selected


def emit(selected, names):
    selected = sorted(selected)
    registered = [p for p in selected if p in REGISTERED]
    docs = [p for p in selected if p not in DOCS_EXCLUDED]
    for name, value in (("packages", selected), ("registered", registered), ("docs", docs)):
        print(f"{name}={json.dumps(value, separators=(',', ':'))}")
        print(f"any_{name}={'true' if value else 'false'}")
    for pkg, why in DOCS_EXCLUDED.items():
        if pkg in selected:
            print(f"::notice::docs skipped for {pkg}: {why}", file=sys.stderr)


def main(argv):
    names = packages()
    if not names:
        sys.exit("no packages found under Julia/ -- is the working directory the repo root?")
    mode = argv[1] if len(argv) > 1 else ""
    if mode == "--all":
        emit(names, names)
    elif mode == "--tag":
        tag = argv[2]
        pkg = tag.rsplit("-v", 1)[0]
        if pkg not in names:
            sys.exit(f"::error::tag {tag!r} does not name a package under Julia/")
        emit({pkg}, names)
    elif mode == "--changed":
        emit(affected([l.strip() for l in sys.stdin if l.strip()], names), names)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
