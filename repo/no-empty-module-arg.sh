# shellcheck shell=bash
# Flag nix files whose first non-blank, non-comment line is `_:`.
# A bare `_:` lambda takes an argument it never uses; modules can be
# plain attrsets instead. Opt out per file with `# keep-arg`.

failed=0

for file in "$@"; do
  if grep -Fq '# keep-arg' "$file"; then
    continue
  fi

  lineno=$(awk '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*_:[[:space:]]*$/ { print NR; exit }
    { exit }
  ' "$file")

  if [ -n "$lineno" ]; then
    printf "%s:%s: unnecessary '_:' lambda; drop it (use a plain attrset) or add '# keep-arg' to opt out\n" "$file" "$lineno" >&2
    failed=1
  fi
done

exit "$failed"
