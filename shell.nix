{ pkgs ? (import ./repo/compat.nix).legacyPackages."${builtins.currentSystem}".util.pkgsForSystem (import ./repo/compat.nix).inputs.nixpkgs builtins.currentSystem, extraArgs ? {} }:

with pkgs;
mkShell ({
  name = "nix-config";
  packages = [
    doppler
    git
    home-manager
    ncurses
    nix
    pre-commit
    shellcheck
    update-all
  ];
  PRE_COMMIT_COLOR = "never";
  SHELLCHECK_OPTS = "-e SC1008";
} // extraArgs)
