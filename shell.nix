# TODO: think of a better way to do this
{ pkgs ? import (import ./pkgs/nixpkgs.nix "nixpkgs") {
  config = import ./config.nix;
  overlays = [
    (import ./pkgs)
    (import ./pkgs/alias.nix)
    (import ./pkgs/pin/overlay.nix)
    (import ./pkgs/functions.nix)
  ];
} }:

with pkgs;
mkShell {
  name = "nix-config";
  packages = [
    doppler
    git
    home-manager
    ldp
    ncurses
    niv
    pre-commit
    shellcheck

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
