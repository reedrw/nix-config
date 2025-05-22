rec {
  description = "a flake for my NixOS and home-manager configs";

  # {{{ Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";
    get-flake.url = "github:ursi/get-flake";

    # flake-parts and its modules
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "unstable";
    };

    NUR = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    ez-configs = {
      url = "github:ehllie/ez-configs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lix.url = "git+https://git.lix.systems/lix-project/lix.git";

    # add pipe operator
    # wait for new release (after dec 2024)
    nil = {
      url = "github:oxalica/nil";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tx-calculator = {
      url = "github:reedrw/tx-calculator";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix/release-25.05";
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

  outputs = { flake-parts, nixpkgs, ... } @ inputs: let
    flake = flake-parts.lib.mkFlake {
      inherit inputs;
    } {
      imports = [
        inputs.ez-configs.flakeModule
        ./repo
      ];

      systems = [ "x86_64-linux" ];
      _module.args = { inherit nixConfig; };
    };

    lib = nixpkgs.lib;
  in lib.fix (lib.foldl' (lib.flip lib.extends) (self: flake) [
    (import ./repo/passInOsConfig.nix inputs)
  ]);
}
