rec {
  description = "a flake for my NixOS and home-manager configs";

  # {{{ Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    NUR.url = "github:nix-community/NUR";
    impermanence.url = "github:nix-community/impermanence";
    flake-compat.url = "github:edolstra/flake-compat";

    # https://gerrit.lix.systems/c/lix/+/1783
    # repl: tab-complete quoted attribute names
    lix.url = "git+https://gerrit.lix.systems/lix?ref=refs/changes/83/1783/8";

    # https://github.com/oxalica/nil/pull/152
    # add pipe operator
    nil.url = "github:q60/nil/pipe-operator-support";

    stylix = {
      url = "github:danth/stylix/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  # }}}

  nixConfig = {
    extra-substituters = [
      "https://reedrw.cachix.org"
      "https://ezkea.cachix.org"
    ];
    extra-trusted-public-keys = [
      "reedrw.cachix.org-1:do9gZInXOYTRPYU+L/x7B90hu1usmnaSFGJl6PN7NC4="
      "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
    ];
    experimental-features = "flakes nix-command pipe-operator";
  };

  outputs = { ... } @ inputs: let
    system = "x86_64-linux";

    pkgs = flake.lib.pkgsForSystem inputs.nixpkgs system;

    flake.lib = import ./lib {
      inherit inputs nixConfig;
    };
  in flake.lib.mkHosts [
    "nixos-desktop"
    "nixos-t480"
    "nixos-t400"
    "nixos-vm"
  ] // {
    inherit pkgs inputs;
    inherit (pkgs) pkgs-unstable lib;

    devShells."${system}".default = import ./shell.nix {
      inherit pkgs;
    };
  };
}
