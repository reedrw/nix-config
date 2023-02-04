#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gron jq niv nix-prefetch

PS4=''
set -x

niv init
niv update

./update-components.sh
