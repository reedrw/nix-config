#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodejs jq
# Updates pins.json: resolves every root (and its transitive
# runtime deps) to the latest npm version via a lockfile-only install, then
# rewrites versions + SRI hashes. Also warns when the vendored packages
# are behind upstream (rebase manually — see FORK.md).
# Run by `update-all` (finds update.sh files) or directly.
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"
script_dir="$PWD"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Resolve roots to the latest versions, including transitive dependencies.
jq '{ dependencies: ([.roots[] | { (.): "latest" }] | add) }' pins.json > "$tmp/package.json"
cd "$tmp"
npm install --package-lock-only --ignore-scripts --no-audit --no-fund --silent

# Rebuild pins.json from the resolved lockfile.
node --input-type=module - "$script_dir/pins.json" <<'EOF'
import { readFileSync, writeFileSync } from "node:fs";
import { basename } from "node:path";

const [pinsPath] = process.argv.slice(2);
const pins = JSON.parse(readFileSync(pinsPath, "utf8"));
const lock = JSON.parse(readFileSync("package-lock.json", "utf8"));

const resolved = {};
for (const [key, entry] of Object.entries(lock.packages ?? {})) {
  if (!key.startsWith("node_modules/")) continue;
  const name = key.slice("node_modules/".length);
  resolved[name] = {
    version: entry.version,
    hash: entry.integrity,
    ...(entry.dependencies && Object.keys(entry.dependencies).length > 0
      ? { dependencies: Object.keys(entry.dependencies).sort() }
      : {}),
  };
}

// Keep roots and their transitive deps only (drop pins no longer reachable).
const keep = new Set();
const queue = pins.roots.map((name) => {
  if (!resolved[name]) throw new Error(`root ${name} not resolved`);
  return name;
});
while (queue.length > 0) {
  const name = queue.pop();
  if (keep.has(name)) continue;
  keep.add(name);
  for (const dep of resolved[name].dependencies ?? []) queue.push(dep);
}

const packages = Object.fromEntries(
  Object.entries(resolved).filter(([name]) => keep.has(name)).sort(([a], [b]) => a.localeCompare(b)),
);
const old = pins.packages;
for (const [name, p] of Object.entries(packages)) {
  const prev = old[name];
  if (prev && prev.version !== p.version) console.log(`${name}: ${prev.version} -> ${p.version}`);
}
writeFileSync(
  pinsPath,
  JSON.stringify({ _comment: pins._comment, roots: pins.roots, packages }, null, 2) + "\n",
);
console.log(`pins.json: ${Object.keys(packages).length} packages pinned`);
EOF
cd "$script_dir"

# Vendored packages (any subdirectory with a package.json that isn't pinned
# above): report drift from upstream. Rebasing is manual — see FORK.md.
for pkg_dir in */; do
  [ -f "$pkg_dir/package.json" ] || continue
  name="$(jq -r .name "$pkg_dir/package.json")"
  vendored="$(jq -r .version "$pkg_dir/package.json")"
  upstream="$(curl -sf "https://registry.npmjs.org/$name" | jq -r '."dist-tags".latest // empty')"
  if [ -z "$upstream" ]; then
    echo "NOTE: vendored $name $vendored — could not determine upstream version"
  elif [ "$vendored" != "$upstream" ]; then
    echo "NOTE: vendored $name $vendored is behind npm $upstream — rebase manually"
  else
    echo "vendored $name $vendored is up to date with npm"
  fi
done
echo "done — run ldp to apply"
