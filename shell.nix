{ pkgs ? import (import ./nixpkgs.nix "nixpkgs") {
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
    nix-output-monitor
    nix-prefetch
    pre-commit
    shellcheck
    wget

    (aliasToPackage {
      update-all = ''
        find -L "$(pwd)/" -type f -name "update-sources.sh" \
        | while read -r updatescript; do
          (
            dir="$(dirname -- "$updatescript")"
            cd "$dir" || exit
            $updatescript
          )
        done
      '';
    })
  ];

  PRE_COMMIT_COLOR = "never";
  SHELLCHECK_OPTS = "-e SC1008";
}
