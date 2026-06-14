---
name: issue
description: Open a GitHub tracking issue on reedrw/nix-config. Use when the
  user wants to track a known problem, upstream bug, workaround, or patch that
  can't be resolved immediately.
---

# issue

Opens a tracking issue on `reedrw/nix-config` for a known problem or workaround.

## Arguments

`$ARGUMENTS` describes the thing to track. If empty, ask the user what the issue
is about before proceeding.

## Issue format

Title: short, imperative — describe the problem or the thing being tracked.

Body:

```markdown
## Problem

<!-- What is broken or suboptimal? Why can't it be fixed right now? -->

## Upstream

<!-- Links to upstream issues, PRs, or commits to watch.
     If none exist, omit this section. -->

## Current remediation

<!-- What is in place right now in this repo to work around the problem?
     Reference specific files and line numbers where relevant.
     If there is no workaround, omit this section. -->
```

Fill in what you know from the conversation and from reading the relevant code.
Leave sections out rather than writing placeholder text if you have nothing
meaningful to say.

## Confirmation required

**Always show the user the proposed title and body and ask for explicit confirmation before creating the issue.** Never create an issue autonomously, even when the content is obvious from context.

## Duplicate check

Before creating, search for existing open issues with similar keywords:

```sh
gh issue list \
  --repo reedrw/nix-config \
  --state open \
  --search "<keywords from title>" \
  --json number,title,url
```

If any results look related, show them to the user and ask whether to proceed or link to an existing issue instead.

## Creating the issue

```sh
gh issue create \
  --repo reedrw/nix-config \
  --label "tracking" \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

If the `tracking` label doesn't exist yet, create it first:

```sh
gh label create tracking \
  --repo reedrw/nix-config \
  --description "Known problems and upstreamed workarounds" \
  --color "e4e669"
```

## After creating

Print the issue URL so the user can open it.
