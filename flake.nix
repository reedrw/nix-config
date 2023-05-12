{
  description = "a flake for my NixOS and home-manager configs";

  # {{{ Inputs
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
  # }}}

  outputs = { self, nixpkgs, master, stable, nixos-hardware, NUR, home-manager, nix-colors, ... } @ inputs: let
    inherit (self) outputs;
    inherit (nixpkgs) lib;
    system = "x86_64-linux";

    config = import ./pkgs/config.nix {
      inherit NUR master stable;
    };

    overlay = import ./pkgs;

    pkgs = import nixpkgs {
      inherit system config;
      overlays = [ overlay ];
    };
  in
  {
    devShells."${system}".default = import ./shell.nix {
      inherit pkgs;
    };

    homeConfigurations = {
      "reed" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs outputs; };
        modules = [
          ./home.nix
          (args: {
            xdg.configFile."nix/inputs/nixpkgs".source = nixpkgs.outPath;
            home.sessionVariables.NIX_PATH = "nixpkgs=${args.config.xdg.configHome}/nix/inputs/nixpkgs$\{NIX_PATH:+:$NIX_PATH}";
            nix.registry.nixpkgs.flake = nixpkgs;
          })
        ];
      };
    };

    nixosConfigurations = {
      nixos-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs outputs; };
        modules = [
          ./system/nixos-desktop.nix
          { nixpkgs = {
            overlays = [ overlay ];
            inherit config;
          }; }
          {
            environment.etc."nix/inputs/nixpkgs".source = nixpkgs.outPath;
            nix.registry.nixpkgs.flake = nixpkgs;
            nix.nixPath = ["nixpkgs=/etc/nix/inputs/nixpkgs"];
          }
        ];
      };
    };
  };
}
