let
  sources = import ./nix/sources.nix { };

  hm-overlay = self: super: {
    home-manager = super.callPackage "${sources.home-manager}/home-manager" { };
  };

  pkgs = import sources.nixpkgs {
    overlays = [
      hm-overlay
      (import ./pkgs)
    ];
    config = import ./config.nix;
  };

in
with pkgs;
mkShell {
  name = "nix-config";
  packages = [
    cargo
    doppler
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
      build = ''
        export NIXPKGS_ALLOW_UNFREE=1
        ci="$(git rev-parse --show-toplevel)/ci.nix"
        if [[ -z "$1" ]]; then
          nix shell nixpkgs#nix-output-monitor -c nom-build "$ci"
        else
          nix shell nixpkgs#nix-output-monitor -c nom-build "$ci" -A "$1"
        fi
      '';
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

  shellHook = ''
    [[ -f .git/hooks/pre-commit ]] || pre-commit install --install-hooks
  '';
}
