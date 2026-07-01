Commit the current changes following this repo's commit conventions.

**Format:** `scope(path): description`

- **scope** — top-level directory: `home-modules`, `nixos-modules`, `pkgs`, `home-configurations`, `nixos-configurations`, `treewide`
- **path** — subdir in parens using `/` separators; omit for `treewide`
- **description** — lowercase imperative, no period

Examples:
```
home-modules(extra/claude-code): apply config at runtime
pkgs(alias/lix): use from nixpkgs instead of flake input
treewide: update to 26.05
```

Common verbs: `init`, `init at <version>`, `use <x>`, `add <x>`, `remove <x>`, `fix <x>`, `pin <x>`, `unpin <x>`.

**Before staging anything:**
1. Run `git diff` (unstaged) and `git diff --cached` (already staged) to see all pending changes.
2. For each modified file, read the full diff of that file (`git diff <file>`) to understand exactly what changed within it — do not assume based on filename alone.
3. Based on what you actually read, decide which changes belong together and group them into one or more commits. A single file may contain changes that belong in different commits — use `git add -p <file>` to stage only the relevant hunks.

**Staging:** Stage files individually by name (`git add <file>`), or by hunk (`git add -p <file>`) when a file contains changes for multiple commits. Never use `git add .` or `git add -A`. If you haven't read a file's diff yet, read it before staging it.

**Commit message:** `scope(path): description` subject line. A body is allowed when useful. Always include a co-author trailer: a blank line, then `Co-Authored-By: <model> <noreply@anthropic.com>` where `<model>` is copied verbatim from the "Environment" section of your system prompt — the exact string following "You are powered by the model" (e.g. `claude-sonnet-5`). Do not translate it into a marketing-style name (e.g. "Claude Sonnet 4.6") or pull a name from a nearby list of "recent models" or from a prior commit/example — those are different values and substituting one is the exact bug this instruction exists to prevent.

If there are many unrelated changes across files, make multiple smaller commits rather than one large one.

**Before running `git commit`:** Draft the commit message(s), then use `AskUserQuestion` to show the user the proposed message and ask for approval. Only proceed with the commit after explicit approval. If the user requests changes to the message, revise and ask again.
