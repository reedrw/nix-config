#!/usr/bin/env bash
# Dev-only typecheck gate for the pi plugin sources (`*.ts` + `lib/**/*.ts`).
#
# tl;dr: `./typecheck.sh` must be clean. Any error it prints is yours.
#
# Runtime never uses this: pi's extension loader (jiti) aliases
# @earendil-works/* to its own modules and the nix package ships no
# node_modules (see default.nix). tsc, however, needs real files on disk, so
# this rebuilds an untracked node_modules of symlinks into the installed pi:
#
#   - every entry of pi's bundled node_modules/* (typebox, zod, …)
#   - @earendil-works/pi-coding-agent -> the package root (pi-monorepo)
#   - @earendil-works/<pkg> -> each bundled package (pi-tui, pi-ai,
#     pi-agent-core, …). These matter: type-only imports like
#     `AssistantMessage` from @earendil-works/pi-ai silently become `any`
#     when the package is missing, which turns into a cascade of
#     "implicitly has an 'any' type" errors at the use sites.
#
# The dir must be REAL (symlinking node_modules itself breaks resolution), and
# @earendil-works/ must be a real dir too (pi-coding-agent has no entry in the
# store's @earendil-works dir). Re-run whenever pi is updated.
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

pi_bin="$(command -v pi)" || {
  echo "typecheck: 'pi' not on PATH — install it first" >&2
  exit 1
}
pi_root="${pi_bin%/bin/pi}"
pi_root="$(readlink -f "$pi_root")"
monorepo="$pi_root/lib/node_modules/pi-monorepo"
bundled="$monorepo/node_modules"

if [ ! -d "$bundled" ]; then
  echo "typecheck: $bundled not found — unexpected pi layout" >&2
  exit 1
fi

rm -rf node_modules
mkdir node_modules
for entry in "$bundled"/*; do
  name="$(basename "$entry")"
  [ "$name" = "@earendil-works" ] && continue # real dir, assembled below
  ln -s "$entry" "node_modules/$name"
done
mkdir node_modules/@earendil-works
ln -s "$monorepo" node_modules/@earendil-works/pi-coding-agent
for pkg in "$bundled"/@earendil-works/*; do
  ln -s "$pkg" "node_modules/@earendil-works/$(basename "$pkg")"
done

exec nix shell nixpkgs#typescript -c tsc --noEmit "$@"
