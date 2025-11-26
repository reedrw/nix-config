{ flake ? import ../repo/compat.nix, inputs ? flake.inputs }:

{
  allowUnfree = true;
  packageOverrides = pkgs: {
    # For some reason applying my overlays in ~/.config/nixpkgs/overlays.nix causes
    # pinned packages to evaluate forever until nix is using 100% RAM. This is a
    # workaround, for legacy nix tools, just grab the packages from the flake.
    # TODO: make the overlays work in ~/.config/nixpkgs/overlays.nix
    flake = flake // { pkgs = flake.legacyPackages.${pkgs.stdenv.hostPlatform.system}; };
  };
  # permittedInsecurePackages = [
  #   "python-2.7.18.8"
  # ];
}
