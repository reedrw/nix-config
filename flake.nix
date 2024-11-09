rec {
  description = "a flake for my NixOS and home-manager configs";

  # {{{ Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    NUR.url = "github:nix-community/NUR";
    impermanence.url = "github:nix-community/impermanence";
    flake-compat.url = "github:edolstra/flake-compat";

    # flake-parts and its modules
    flake-parts.url = "github:hercules-ci/flake-parts";
    # flake-parts.inputs.nixpkgs-lib.follows = "unstable";

    # https://github.com/ehllie/ez-configs/pull/12
    # Allow setting user module names for system hm modules
    ez-configs.url = "github:ehllie/ez-configs/user-home-modules";

    # https://gerrit.lix.systems/c/lix/+/1783
    # repl: tab-complete quoted attribute names
    lix.url = "git+https://gerrit.lix.systems/lix?ref=refs/changes/83/1783/10";

    # https://github.com/oxalica/nil/pull/152
    # add pipe operator
    nil.url = "github:q60/nil/pipe-operator-support";

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
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

  outputs = { flake-parts, ... } @ inputs: flake-parts.lib.mkFlake {
    inherit inputs;
  } {
    imports = [
      inputs.ez-configs.flakeModule
      ./repo
    ];

    systems = [ "x86_64-linux" ];
    _module.args = { inherit nixConfig; };
  };
}
