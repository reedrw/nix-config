{ inputs ? (import ../repo/compat.nix).inputs }:

{
  allowUnfree = true;
  packageOverrides = pkgs: {}
    // import ./pin/overlay.nix pkgs pkgs
    // import ./branches.nix inputs pkgs pkgs;
}
