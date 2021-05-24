#! /usr/bin/env nix-shell
#! nix-shell -i bash -p niv nix-prefetch-github

PS4=''
set -x

niv update

{
  nix-prefetch-github neovim neovim --rev nightly
  echo
} > nightly.json
