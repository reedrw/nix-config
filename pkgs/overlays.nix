{ flake ? import ../repo/compat.nix, inputs ? (flake.inputs // { self = flake; }) }:

[
  (import ./branches.nix inputs)
  (import ./. inputs)
  (import ./alias.nix)
  (import ./functions.nix inputs)
]
