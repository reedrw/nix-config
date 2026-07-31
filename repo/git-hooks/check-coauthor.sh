#!/usr/bin/env nix-shell
#! nix-shell -i bash -p git

# commit-msg hook: require a Co-Authored-By trailer on AI-agent commits.
# An agent commit is detected by the COAUTHOR_REQUIRED env var, which the
# wrapped opencode binary exports into its process environment — every command
# it spawns (including git) inherits it. Manual CLI commits never see the var,
# even when they use `git commit -m`, so only agent commits are enforced.
#
# `git interpret-trailers --parse` only emits lines from the trailer block
# (the last paragraph, after a blank line), so a trailer in the middle of the
# message body doesn't count.

msg_file="${1:?commit-msg hook requires the commit message file as \$1}"

if [[ -z "${COAUTHOR_REQUIRED:-}" ]]; then
  exit 0
fi

trailer="$(
  git interpret-trailers --parse <"$msg_file" 2>/dev/null \
    | grep -i '^Co-Authored-By:'
)"

if [[ -z "$trailer" ]] || ! grep -qE '^Co-Authored-By: [^<>]+ <[^<>]+>$' <<<"$trailer"; then
  cat >&2 <<'EOF'
Commit message is missing a Co-Authored-By trailer. Append it after a
blank line at the end of the message:

  Co-Authored-By: <your-exact-model-id> <noreply@your-provider>

Use the exact model ID you ran as (e.g. deepseek-v4-flash), not a
marketing name.
EOF
  exit 1
fi
