#!/usr/bin/env python3
"""why-diff: explain the difference between two Nix closures.

Instead of `nix store diff-closures`' flat "name: old -> new" table, this shows
a tree of the *version transitions*, rooted at what pulled them in:

    SIZE: 8.71 GiB → 8.71 GiB (+1.5 MiB)

    └── pi-coding-agent-0.85.1 ·
        ├── nodejs 24.19.0 → 24.20.0 (+61.2 MiB)
        │   └── ...

Leaves are package versions that are new in the second closure, labelled with
the versions they replaced. Parents that only carry the change (rebuilt, same
version) are greyed with `·`. Same-version store-path swaps and NixOS/HM
plumbing paths are counted in the footer but omitted from the tree.

Usage: why-diff <old-installable> <new-installable>
"""

import json
import re
import subprocess
import sys
from collections import defaultdict, deque

PLUMBING = re.compile(
    r"^(etc|system-path|system-units|systemd|unit-|nixos-system-|home-manager-|"
    r"hm-|users-groups|activate|etc-|.+\.drv)"
)
OUTPUT_SUFFIX = re.compile(
    r"-(dev|bin|lib|man|info|doc|out|devdoc|libexec|static|debug|corepack|npm|source|"
    r"bwrap|init|fhsenv-profile|fhsenv-rootfs)$"
)

GREEN = "\033[32m" if sys.stdout.isatty() else ""
RED = "\033[31m" if sys.stdout.isatty() else ""
DIM = "\033[2m" if sys.stdout.isatty() else ""
RESET = "\033[0m" if sys.stdout.isatty() else ""
# when piped (e.g. into the CI PR comment), emit lines prefixed with +/- so the
# output renders with diff syntax highlighting inside a ```diff block
DIFF_MODE = not sys.stdout.isatty()


def out(kind, text):
    """print a report line; 'add'/'del'/'ctx' map to +/-/space in diff mode"""
    print(f"{ {'add': '+', 'del': '-', 'ctx': ' '}[kind] }{text}" if DIFF_MODE else text)


def human(nbytes):
    sign = "-" if nbytes < 0 else ""
    nbytes = abs(nbytes)
    for unit, threshold in (("TiB", 1 << 40), ("GiB", 1 << 30), ("MiB", 1 << 20), ("KiB", 1 << 10)):
        if nbytes >= threshold:
            return f"{sign}{nbytes / threshold:.1f} {unit}"
    return f"{sign}{nbytes} B"


def closure(installable):
    out = subprocess.run(
        ["nix", "path-info", "-r", "--json", installable],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out)


def main():
    global GREEN, RED, DIM, RESET, DIFF_MODE
    args = sys.argv[1:]
    DIFF_MODE = "--diff" in args
    args = [a for a in args if a != "--diff"]
    if len(args) != 2:
        sys.exit(__doc__)
    if sys.stdout.isatty() and not DIFF_MODE:
        GREEN, RED, DIM, RESET = "\033[32m", "\033[31m", "\033[2m", "\033[0m"
    old, new = closure(args[0]), closure(args[1])

    def nv(path):
        return path.rsplit("/", 1)[-1].split("-", 1)[1]

    def deep_clean(path):
        name = nv(path)
        prev = None
        while prev != name:
            prev = name
            name = OUTPUT_SUFFIX.sub("", name)
        return name

    def base(name):
        return re.sub(r"-[0-9][0-9a-zA-Z.+~-]*$", "", name)

    old_set = {p["path"] for p in old}
    refs = {p["path"]: set(p["references"]) for p in new}

    # toplevel: referenced by no *other* path (paths may self-reference)
    roots = [
        p["path"]
        for p in new
        if not any(p["path"] in refs[q["path"]] for q in new if q["path"] != p["path"])
    ]
    toplevel = max(roots, key=lambda r: (re.match(r"[a-z0-9]{32}-nixos-system-", r), 0), default=None)
    if toplevel is None:
        toplevel = max(roots, key=lambda r: refs.get(r, 0))

    # BFS from toplevel along references: shortest chain to every path
    parent = {toplevel: None}
    q = deque([toplevel])
    while q:
        n = q.popleft()
        for child in refs.get(n, []):
            if child not in parent:
                parent[child] = n
                q.append(child)

    # same, but for the old closure (to explain removals)
    old_refs = {p["path"]: set(p["references"]) for p in old}
    old_referenced = {r for p in old for r in p["references"]}
    old_toplevel = next(
        p["path"]
        for p in old
        if not any(p["path"] in old_refs[q["path"]] for q in old if q["path"] != p["path"])
    )
    old_parent = {old_toplevel: None}
    q = deque([old_toplevel])
    while q:
        n = q.popleft()
        for child in old_refs.get(n, []):
            if child not in old_parent:
                old_parent[child] = n
                q.append(child)

    old_by_nv = defaultdict(int)
    for p in old:
        old_by_nv[nv(p["path"])] += 1
    old_nar = {p["path"]: p.get("narSize", 0) for p in old}

    added = [p for p in new if p["path"] not in old_set]
    removed = [p for p in old if p["path"] not in {p["path"] for p in new}]

    # per-cleaned-name sizes (net change is what a leaf label shows)
    added_size, removed_size = defaultdict(int), defaultdict(int)
    for p in added:
        added_size[deep_clean(p["path"])] += p.get("narSize", 0)
    for p in removed:
        removed_size[deep_clean(p["path"])] += old_nar.get(p["path"], 0)

    # versions that were (partly) replaced: fewer copies now than before
    old_cnt, new_cnt = defaultdict(int), defaultdict(int)
    for p in old:
        old_cnt[deep_clean(p["path"])] += 1
    for p in new:
        new_cnt[deep_clean(p["path"])] += 1
    old_versions_by_base = defaultdict(set)
    for nm, cnt in old_cnt.items():
        b = base(nm)
        if cnt > new_cnt.get(nm, 0):
            old_versions_by_base[b].add(nm[len(b) + 1:])

    def short_chain(path, parents):
        """toplevel->path chain, plumbing squeezed out"""
        chain, node = [], path
        while node is not None:
            chain.append(deep_clean(node))
            node = parents.get(node)
        chain.reverse()
        out = [nm for nm in chain if not PLUMBING.match(nm)]
        return [nm for i, nm in enumerate(out) if i == 0 or out[i - 1] != nm]

    tree = {}
    new_versions = {p["path"] for p in added if old_by_nv[nv(p["path"])] == 0}
    for path in sorted(new_versions):
        chain = short_chain(path, parent)
        if not chain:
            # an added path whose whole chain is plumbing (e.g. a renamed
            # toplevel after a nixpkgs bump) is infra churn, not a transition
            continue
        cur, prev = tree, None
        for nm in chain:
            prev = cur.setdefault(nm, {"__new__": [], "__gone__": [], "__kids__": {}})
            cur = prev["__kids__"]
        prev.setdefault("__new__", []).append(path)

    # packages whose last version vanished (no version of the base remains):
    # traced through the OLD closure and attached under the deepest node they
    # share with the tree, so removals appear in red next to what dropped them
    new_bases = {base(nm) for nm in new_cnt}
    gone_paths = [
        p["path"]
        for p in removed
        if not PLUMBING.match(deep_clean(p["path"])) and base(deep_clean(p["path"])) not in new_bases
    ]
    for path in sorted(gone_paths):
        chain = short_chain(path, old_parent)
        if not chain:
            continue
        node, k = tree, 0
        while k < len(chain) and chain[k] in node:
            node = node[chain[k]]["__kids__"]
            k += 1
        prev = None
        for nm in chain[k:]:
            prev = node.setdefault(nm, {"__new__": [], "__gone__": [], "__kids__": {}})
            node = prev["__kids__"]
        prev.setdefault("__gone__", []).append(path)

    def transition(nm):
        """('openssl 3.6.3 → 3.6.4 (+x MiB)', kind) — swaps are neutral; only
        brand-new packages (no previous version at all) count as additions"""
        b = base(nm)
        newv = nm[len(b) + 1:]
        olds = sorted(v for v in old_versions_by_base.get(b, ()) if v != newv)
        delta = added_size.get(nm, 0) - removed_size.get(nm, 0)
        size = f" ({human(delta)})" if abs(delta) >= 8 * 1024 else ""
        if not olds:
            return f"{GREEN}{b} {newv}{RESET}{size}", "add"
        return f"{b} {', '.join(olds)} → {newv}{size}", "ctx"

    total_old = sum(p.get("narSize", 0) for p in old)
    total_new = sum(p.get("narSize", 0) for p in new)
    churn = [p for p in added if p["path"] not in new_versions]

    out("ctx", f"SIZE: {human(total_old)} → {human(total_new)} ({human(total_new - total_old)})")
    out(
        "ctx",
        f"{DIM}total: {len(added)} paths in, {len(removed)} out ({human(total_new - total_old)} net); "
        f"omitted from tree: {len(churn)} same-version swaps{RESET}",
    )

    def render(node, prefix="", depth=0):
        entries = [k for k in sorted(node) if not k.startswith("__")]
        for i, nm in enumerate(entries):
            nd = node[nm]
            kids = nd["__kids__"]
            sub = [k for k in kids if not k.startswith("__")]
            last = i == len(entries) - 1
            ext = "    " if last else "│   "
            if nd["__new__"]:
                label, kind = transition(nm)
                marker = ""
            elif nd["__gone__"]:
                b = base(nm)
                delta = -removed_size.get(nm, 0)
                size = f" ({human(delta)})" if abs(delta) >= 8 * 1024 else ""
                label = f"{RED}{b} {nm[len(b) + 1:]}{RESET}{size}"
                marker, kind = f" {DIM}✗{RESET}", "del"
            else:
                label, marker, kind = nm, f" {DIM}·{RESET}", "ctx"
            tail = f"   ({len(sub)} deps)" if len(sub) > 3 and depth >= 1 else ""
            out(kind, f"{prefix}{'└── ' if last else '├── '}{label}{marker}{tail}")
            render(kids, prefix + ext, depth + 1)

    if tree:
        render(tree)
    else:
        out("ctx", "No version transitions.")


if __name__ == "__main__":
    main()
