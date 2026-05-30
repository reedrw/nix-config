{ flake ? import ../repo/compat.nix, inputs ? (flake.inputs // { self = flake; }) }:

[
  (import ./branches.nix inputs)
  (import ./.)
  (import ./pin/overlay.nix)
  (import ./alias.nix)
  (import ./functions.nix inputs)
]
