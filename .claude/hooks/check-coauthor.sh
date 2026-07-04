#!/usr/bin/env bash
# PreToolUse hook: validate the Co-Authored-By trailer on `git commit -m`
# commands against the model ID recorded in the session transcript.
# Denies with the exact expected trailer so a wrong guess self-corrects.

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<< "$input")
transcript=$(jq -r '.transcript_path // empty' <<< "$input")

[[ "$cmd" == *"git commit"* ]] || exit 0
[[ "$cmd" == *" -m"* || "$cmd" == *"--message"* ]] || exit 0
[[ -f "$transcript" ]] || exit 0

model=$(jq -r 'select(.type == "assistant") | .message.model // empty' "$transcript" 2>/dev/null | tail -1)
[[ -n "$model" ]] || exit 0

trailer="Co-Authored-By: ${model} <noreply@anthropic.com>"
if [[ "$cmd" != *"$trailer"* ]]; then
  jq -n --arg r "Commit message must include this exact co-author trailer (verified against the session transcript): ${trailer}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
fi
