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
      update-all = let
        blue = ''"$(tput setaf 4)"'';
        green = ''"$(tput setaf 2)"'';
        reset = ''"$(tput sgr0)"'';
        dots = "${blue}....................................................................${reset}";
      in ''
        find . -name update-sources.sh -execdir sh -c 'echo -e "Running ${green}$(realpath {})\n${dots}" && {} && echo' \;
      '';
    })
  ];

  PRE_COMMIT_COLOR = "never";
  SHELLCHECK_OPTS = "-e SC1008";
}
