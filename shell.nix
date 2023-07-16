{ pkgs ? import (import ./pkgs/nixpkgs.nix "nixpkgs") {
  config = import ./config.nix;
  overlays = [ (import ./pkgs) ];
} }:

with pkgs;
mkShell {
  name = "nix-config";
  packages = [
    cargo
    doppler
    expect
    gcc
    git
    gron
    home-manager
    jq
    niv
    nix-prefetch
    pre-commit
    shellcheck
    wget

    (aliasToPackage {
      update-all = ''
        find . -name update-sources.sh -execdir sh -c "realpath {} && {}" \;
      '';
    })
  ];

  PRE_COMMIT_COLOR = "never";
  SHELLCHECK_OPTS = "-e SC1008";
}
