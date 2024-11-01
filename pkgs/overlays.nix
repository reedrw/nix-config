{ flake ? import ../repo/compat.nix, inputs ? flake.inputs }:

[
  (import ./.)
  (import ./branches.nix inputs)
  (import ./pin/overlay.nix)
  (import ./alias.nix inputs)
  (import ./functions.nix)
]
