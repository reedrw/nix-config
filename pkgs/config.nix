{ inputs ? (import ../lib/compat.nix).inputs }:

{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: {}
    // import ./pin/overlay.nix pkgs pkgs
    // import ./branches.nix inputs pkgs pkgs;
}
