---
name: commit-message-style
description: Commit message conventions for this repo — scope-prefixed, lowercase, imperative, concise
metadata:
  type: feedback
---

Commit messages follow a `scope(path): description` format:

- **Scope** is the top-level directory: `home-modules`, `nixos-modules`, `pkgs`, `home-configurations`, `nixos-configurations`, or `treewide` for cross-cutting changes
- **Path** is the subdirectory path in parentheses, using `/` separators: `home-modules(extra/claude-code)`, `pkgs(pin)`, `nixos-modules(core/run0)`
- **Description** is lowercase, imperative, no period: `init at 7.2.5`, `fix tailscale incompatibility`, `remove unneeded pkgs-unstable`

Common description patterns:
- `init` or `init at <version>` — introducing something new
- `use <x>` — switching to an alternative
- `add <x>` — adding a feature/option/item
- `remove <x>` — deleting something
- `fix <x>` — bug fix
- `pin <x>` / `unpin <x>` — version pinning changes

**Examples:**
```
home-modules(extra/claude-code): apply config at runtime
pkgs(alias/lix): use from nixpkgs instead of flake input
nixos-modules(networking/mullvad): fix tailscale incompatibility
pkgs(easyeffects): init at 7.2.5
treewide: update to 26.05
```

No body, no co-author lines, no bullet points — just the one-line subject.
