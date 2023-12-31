{
  description = "a flake for my NixOS and home-manager configs";

  # {{{ Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    master.url = "github:nixos/nixpkgs";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    NUR.url = "github:nix-community/NUR";
    nix-colors.url = "github:misterio77/nix-colors";
    impermanence.url = "github:nix-community/impermanence";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  # }}}

  outputs = { self, nixpkgs, master, unstable, nixos-hardware, NUR, home-manager, nix-colors, impermanence, ... } @ inputs: let
    inherit (self) outputs;
    system = "x86_64-linux";

    pkgs = flake.lib.pkgsForSystem system;

    flake.lib = import ./lib {
      inherit inputs outputs self;
    };
  in flake.lib.mkHosts [
    "nixos-desktop"
    "nixos-t480"
  ] // {
    inherit pkgs;

    devShells."${system}".default = import ./shell.nix {
      inherit pkgs;
    };
  };
}
