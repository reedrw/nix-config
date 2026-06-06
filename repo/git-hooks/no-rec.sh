#!/usr/bin/env nix-shell
#! nix-shell -i bash -p ast-grep

# Flag nix files that use the `rec` keyword.
# Recursive attrsets make it easy to introduce accidental shadowing;
# prefer self-referential build functions or lib.fix instead.

failed=0

rule="$(cat <<'EOF'
id: no-rec
severity: error
message: "avoid 'rec'; use self-referential build-function args or lib.fix instead"
language: Nix
rule:
  kind: rec_attrset_expression
EOF
)"

if [ "${#@}" -gt 0 ]; then
  ast-grep scan --inline-rules "$rule" "$@" || failed=1
fi

exit "$failed"
