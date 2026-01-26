#! /usr/bin/env bash

set -x
set -e

toplevel="$(git rev-parse --show-toplevel)"
flake="builtins.getFlake \"$toplevel\""

updateScript="$(nix build --impure --no-link --print-out-paths --expr "($flake).packages.x86_64-linux.wheel-wizard.passthru.updateScript")"

exec "$updateScript"
