#!/usr/bin/env bash
# PreToolUse hook: deny `ldp --switch <target>` unless <target> is the
# current hostname. Bare `ldp --switch` (defaults to $(hostname)) is fine.

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<< "$input")
[[ -n "$cmd" ]] || exit 0

if [[ "$cmd" =~ ^ldp[[:space:]]+--switch[[:space:]]+([^[:space:]]+) ]]; then
  target="${BASH_REMATCH[1]}"
  if [ "$target" != "$(hostname)" ]; then
    jq -n --arg r "Targeted \`ldp --switch $target\` is not allowed — switch target must be the current hostname ($(hostname)). Run a bare \`ldp --switch\`, or use \`ldp --build <target>\` to build other hosts." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  fi
fi
