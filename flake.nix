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

    nix-colors.url = "github:misterio77/nix-colors";

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

  };

  outputs = { self, nixpkgs, master, stable, nixos-hardware, NUR, home-manager, nix-colors, ... } @ inputs: let
    inherit (self) outputs;
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ (import ./pkgs) ];
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
    };
  in
  {
    homeConfigurations = {
      "reed" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        # pkgs = nixpkgs.legacyPackages."x86_64-linux";
        extraSpecialArgs = { inherit inputs outputs nix-colors; };
        modules = [ ./home.nix ];
      };
    };
  };
}
