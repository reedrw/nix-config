---
description: Commit changes following this repo's commit conventions
---

Commit the current changes following this repo's commit conventions.

**Format:** `scope(path): description`

- **scope** — top-level directory: `home-modules`, `nixos-modules`, `pkgs`, `home-configurations`, `nixos-configurations`, `repo`, `.claude`, `actions` (for `.github/workflows`), `treewide`
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

**Commit message:** `scope(path): description` subject line. A body is allowed when useful. Include a co-author trailer: a blank line, then `Co-Authored-By: <your-exact-model-id> <noreply@your-provider>` where `<your-exact-model-id>` is the exact model ID you are running as (e.g. `deepseek-v4-flash`), not a marketing name, and `<your-provider>` is the API provider (e.g. `noreply@deepseek.com`). A `commit-msg` git hook rejects agent commits (flagged via the `COAUTHOR_REQUIRED` env var) if this trailer is missing or not in `Name <email>` form, so get it right the first time.

If there are many unrelated changes across files, make multiple smaller commits rather than one large one.

**Before running `git commit`:** Draft the commit message(s), then show the user the proposed message(s) and ask for approval in the chat. Only proceed with the commit after explicit approval. If the user requests changes to the message, revise and ask again.
