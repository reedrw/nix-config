{ flake ? import ../repo/compat.nix }:

{
  allowUnfree = true;
  packageOverrides = pkgs: {
    # For some reason applying my overlays in ~/.config/nixpkgs/overlays.nix causes
    # pinned packages to evaluate forever until nix is using 100% RAM. This is a
    # workaround, for legacy nix tools, just grab the packages from the flake.
    # TODO: make the overlays work in ~/.config/nixpkgs/overlays.nix
    flake = flake // { pkgs = flake.legacyPackages.${pkgs.stdenv.hostPlatform.system}; };
  };
  permittedInsecurePackages = [
    # bitwarden-desktop 2026.3.1 requires electron 39, which is EOL but fully patched (39.8.10).
    # Remove once bitwarden upgrades to electron 40+.
    "electron-39.8.10"
  ];
}
