#! /usr/bin/env nix-shell
#! nix-shell -i bash -p niv

PS4=''
set -x

niv init
niv update
