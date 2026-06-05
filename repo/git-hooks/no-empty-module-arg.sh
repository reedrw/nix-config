#!/usr/bin/env nix-shell
#! nix-shell -i bash -p ast-grep

# Flag nix files whose top-level expression is `_: <expr>`.
# A bare `_:` lambda takes an argument it never uses; modules can be
# plain attrsets instead.

failed=0

rule="$(cat <<'EOF'
id: no-empty-module-arg
severity: error
message: "unnecessary '_:' lambda; drop it (use a plain attrset) or add '# keep-arg' to opt out"
language: Nix
rule:
  pattern: "_: $BODY"
  inside:
    kind: source_code
    stopBy: neighbor
constraints:
  BODY:
    not:
      kind: function_expression
EOF
)"

files=()
for file in "$@"; do
  if ! grep -Fq '# keep-arg' "$file"; then
    files+=("$file")
  fi
done

if [ "${#files[@]}" -gt 0 ]; then
  ast-grep scan --inline-rules "$rule" "${files[@]}" || failed=1
fi

exit "$failed"
