{ pkgs ? (import ./repo/compat.nix).legacyPackages."${builtins.currentSystem}" }:

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
    nix
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
