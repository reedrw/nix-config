{
  description = "a flake for my NixOS and home-manager configs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    master.url = "github:nixos/nixpkgs";
    stable.url = "github:nixos/nixpkgs/nixos-22.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    NUR.url = "github:nix-community/NUR";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    nix-colors.url = "github:misterio77/nix-colors";

    # home-manager non-flake dependencies
    ncmpcpp = {
      url = "github:ncmpcpp/ncmpcpp";
      flake = false;
    };

    mpv-scripts = {
      url = "github:ObserverOfTime/mpv-scripts";
      flake = false;
    };
    mpv-webm = {
      url = "github:ekisu/mpv-webm";
      flake = false;
    };
    mpv_thumbnail_script = {
      url = "github:blankname/mpv_thumbnail_script/nil-props";
      flake = false;
    };

    ranger-archives = {
      url = "github:maximtrp/ranger-archives";
      flake = false;
    };

    # system
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # system non-flake dependencies
    distro-grub-themes = {
      url = "github:AdisonCavani/distro-grub-themes";
      flake = false;
    };

    Lists = {
      url = "github:blocklistproject/Lists";
      flake = false;
    };

    "Ultimate.Hosts.Blacklist" = {
      url = "github:Ultimate-Hosts-Blacklist/Ultimate.Hosts.Blacklist";
      flake = false;
    };

    hosts = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };

  };

  outputs = { self, nixpkgs, master, stable, nixos-hardware, NUR, home-manager, nix-colors, ... } @ inputs: let
    inherit (self) outputs;
    inherit (nixpkgs) lib;
    system = "x86_64-linux";

    config = {
      allowUnfree = true;
      allowBroken = true;
      packageOverrides = pkgs: rec {
        nur = import NUR {
          inherit pkgs;
          nurpkgs = pkgs;
        };
        nurPkgs = nur.repos.reedrw;
        fromBranch = {
          master = import master { inherit (pkgs) config system; };
          stable = import stable { inherit (pkgs) config system; };
        };
      };
    };

    overlay = import ./pkgs;

    pkgs = import nixpkgs {
      inherit system config;
      overlays = [ overlay ];
    };
  in
  {
    homeConfigurations = {
      "reed" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        # pkgs = nixpkgs.legacyPackages."x86_64-linux";
        extraSpecialArgs = { inherit inputs outputs; };
        modules = [ ./home.nix ];
      };
    };

    nixosConfigurations = {
      nixos-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs outputs; };
        modules = [
          ./system/nixos-desktop.nix
          {
            nixpkgs = {
              overlays = [ overlay ];
              inherit config;
            };
          }
        ];
      };
    };

    devShells."${system}".default = with pkgs; mkShell {
      name = "nix-config";
      packages = [
        (callPackage "${home-manager}/home-manager" {})
        cargo
        doppler
        expect
        gcc
        git
        gron
        jq
        niv
        nix-output-monitor
        nix-prefetch
        pre-commit
        shellcheck
        wget

        (aliasToPackage {
          build = ''
            export NIXPKGS_ALLOW_UNFREE=1
            ci="$(git rev-parse --show-toplevel)/ci.nix"
            if [[ -z "$1" ]]; then
              ${nix-output-monitor}/bin/nom-build "$ci"
            else
              ${nix-output-monitor}/bin/nom-build "$ci" -A "$1"
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
    };
  };
}
