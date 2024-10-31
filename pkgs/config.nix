{ inputs ? (import ../repo/compat.nix).inputs }:

{
  allowUnfree = true;
  packageOverrides = pkgs: {}
    # TODO: figure out a way to apply version overrides to legacy nix
    # tools like nix-shell
    # // import ./pin/overlay.nix pkgs pkgs
    // import ./branches.nix inputs pkgs pkgs;
}
