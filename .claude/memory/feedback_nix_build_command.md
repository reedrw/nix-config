---
name: Use nix build .#<pkg> directly
description: Prefer `nix build .#<pkg>` over compat.nix or nix-build for building flake outputs
type: feedback
---

Use `nix build .#<pkg>` directly to build flake packages. Flakes are set up in this repo — don't fall back to `nix-build repo/compat.nix` or other legacy approaches.

**Why:** The flake is the canonical build entry point; compat.nix is only for legacy tooling that doesn't support flakes.

**How to apply:** Any time building or testing a package in this repo, use `nix build .#<attr>`.
