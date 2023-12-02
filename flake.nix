{
  description = "a flake for my NixOS and home-manager configs";

  # {{{ Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    master.url = "github:nixos/nixpkgs";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    NUR.url = "github:nix-community/NUR";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    impermanence.url = "github:nix-community/impermanence";

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
      url = "github:AdisonCavani/distro-grub-themes?rev=15b20532b0d443dbd118b179ac7b63cba9499511";
      flake = false;
    };

    # https://github.com/alacritty/alacritty/issues/6884
    alacritty = {
      url = "github:alacritty/alacritty?rev=578e08486dfcdee0b2cd0e7a66752ff50edc46b8";
      flake = false;
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
    inherit (flake) lib;

    devShells."${system}".default = import ./shell.nix {
      inherit pkgs;
    };

    legacyPackages."${system}".default = pkgs;
  };

}
