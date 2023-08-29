{
  description = "a flake for my NixOS and home-manager configs";

  # {{{ Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    master.url = "github:nixos/nixpkgs";
    stable.url = "github:nixos/nixpkgs/nixos-23.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    NUR.url = "github:nix-community/NUR";
    home-manager = {
      url = "github:nix-community/home-manager";
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

    an-anime-game-launcher = {
      url = "github:an-anime-team/an-anime-game-launcher/next";
      flake = false;
    };

    the-honkers-railway-launcher = {
      url = "github:an-anime-team/the-honkers-railway-launcher/next";
      flake = false;
    };

    alacritty = {
      url = "github:alacritty/alacritty";
      flake = false;
    };
  };
  # }}}

  outputs = { self, nixpkgs, master, stable, nixos-hardware, NUR, home-manager, nix-colors, impermanence, ... } @ inputs: let
    inherit (self) outputs;
    system = "x86_64-linux";

    config = import ./pkgs/config.nix {
      inherit NUR master stable;
    };

    overlay = import ./pkgs;

    nixpkgs-options = {
      nixpkgs = {
        overlays = [ overlay ];
        inherit config;
      };
    };

    pkgs = import nixpkgs (nixpkgs-options.nixpkgs // {
      inherit system;
    });

    # Get a list of machine-specific home-manager modules.
    # This is necessary since I use hm both as a NixOS module, and as a flake output.
    machineSpecificHM = host:
      let
        homeDirPath = ./system + "/${host}/home";
        homeDirContents = builtins.attrNames (builtins.readDir homeDirPath);
      in
      builtins.map (x: homeDirPath + "/${x}") homeDirContents;

    commonHMModules = [
      ./home.nix
      nixpkgs-options
      (args: {
        xdg.configFile."nix/inputs/nixpkgs".source = nixpkgs.outPath;
        home.sessionVariables.NIX_PATH = "nixpkgs=${args.config.xdg.configHome}/nix/inputs/nixpkgs$\{NIX_PATH:+:$NIX_PATH}";
        nix.registry.nixpkgs.flake = nixpkgs;
      })
    ];

    commonNixOSModules = [
        impermanence.nixosModule
        nixpkgs-options
        {
          environment.etc."nix/inputs/nixpkgs".source = nixpkgs.outPath;
          nix.registry.nixpkgs.flake = nixpkgs;
          nix.nixPath = ["nixpkgs=/etc/nix/inputs/nixpkgs"];
        }
    ];

    # Takes a hostname as argument and creates a set containing 2 NixOS configurations for that host:
    # - one with home-manager enabled, which is used on the machine itself
    # - one without home-manager, which is used for building in GitHub Actions
    # This is necessary because the size of my home-manager config makes my NixOS config closures
    # too large to build in GitHub Actions.
    mkNixOSConfiguration = name:
    let
      modules-noHM = commonNixOSModules ++ [
        (./. + "/system/${name}/configuration.nix")
      ];
      modules = modules-noHM ++ [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.reed.imports = commonHMModules ++ machineSpecificHM name;
        }
      ];
    in {
      "${name}" = nixpkgs.lib.nixosSystem {
        inherit system modules;
        specialArgs = { inherit inputs outputs nixpkgs-options; };
      };
      "${name}-no-home-manager" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs outputs nixpkgs-options; };
        modules = modules-noHM;
      };
    };
  in
  {
    devShells."${system}".default = import ./shell.nix {
      inherit pkgs;
    };

    homeConfigurations = {
      "reed@nixos-desktop" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs outputs; };
        modules = commonHMModules ++ machineSpecificHM "nixos-desktop";
      };
      "reed@nixos-t480" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs outputs; };
        modules = commonHMModules ++ machineSpecificHM "nixos-t480";
      };
    };

    nixosConfigurations = let configs = [
      (mkNixOSConfiguration "nixos-desktop")
      (mkNixOSConfiguration "nixos-t480")
    ]; in builtins.foldl' (a: b: a // b) {} configs;
  };
}
