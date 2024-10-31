{ inputs ? (import ../repo/compat.nix).inputs }:

[
  (import ./.)
  (import ./branches.nix inputs)
  (import ./pin/overlay.nix)
  (import ./alias.nix inputs)
  (import ./functions.nix)
]
