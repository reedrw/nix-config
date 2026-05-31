Commit the current changes following this repo's commit conventions (see Working Conventions > Commits in CLAUDE.md).

**Before staging anything:**
1. Run `git diff` (unstaged) and `git diff --cached` (already staged) to see all pending changes.
2. For each modified file, read the full diff of that file (`git diff <file>`) to understand exactly what changed within it — do not assume based on filename alone.
3. Based on what you actually read, decide which changes belong together and group them into one or more commits. If a file contains unrelated changes, note that when writing the commit message.

**Staging:** Stage files individually by name (`git add <file>`). Never use `git add .` or `git add -A`. If you haven't read a file's diff yet, read it before staging it.

**Commit message:** One line, `scope(path): description` format. No body, no bullet points, no co-author lines.

If there are many unrelated changes across files, make multiple smaller commits rather than one large one.
