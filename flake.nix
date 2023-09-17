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

    # Nixpkgs setup
    ########################################
    nixpkgs-options = {
      nixpkgs = {
        overlays = [ (import ./pkgs) ];
        config = import ./pkgs/config.nix {
          inherit NUR master stable;
        };
      };
    };

    pkgs = import nixpkgs (nixpkgs-options.nixpkgs // {
      inherit system;
    });

    lib = pkgs.lib;

    # mkHost :: String -> AttrSet
    ########################################
    # Takes a hostname as argument and returns a set of flake outputs
    # for that host. This is then merged into the top-level outputs.
    #
    # Example:
    # mkHost "nixos-desktop"
    #
    # Returns a set with the following attributes:
    # {
    #   homeConfigurations = { "reed@nixos-desktop" = { ... }; };
    #   nixosConfigurations = {
    #     "nixos-desktop" = { ... };
    #     "nixos-desktop-no-home-manager" = { ... };
    #   };
    # }
    #  - `homeConfigurations` contains a home-manager configuration for ${username}@${host}
    #  - `nixosConfigurations` contains a 2 NixOS configurations for ${host}:
    #    - `${host}` is a NixOS configuration with home-manager enabled
    #    - `${host}-no-home-manager` is a NixOS configuration with home-manager disabled.
    #      This is used to build in Github Actions, to reduce unnecessary build time from
    #      building the home-manager configuration within the NixOS configuration.
    mkHost = host:
    let
      # For now, repo is only set up for 1 home-manager user
      username = "reed";

      # NixOS configuration imports, minus home-manager
      modules-noHM = [
        (./. + "/system/${host}/configuration.nix")
        impermanence.nixosModule
        nixpkgs-options
        {
          environment.etc."nix/inputs/nixpkgs".source = nixpkgs.outPath;
          nix.registry.nixpkgs.flake = nixpkgs;
          nix.nixPath = ["nixpkgs=/etc/nix/inputs/nixpkgs"];
        }
      ];

      # Home-manager configuration imports
      hm.modules = let
        # Each host has a directory for home-manager config in ./system/${host}/home.
        # Any .nix files in that directory will be imported as part of the home-manager
        # configuration for that host.
        homeDirPath = ./system + "/${host}/home";
        homeDirContents = builtins.attrNames (builtins.readDir homeDirPath);
        perHost = builtins.map (x: homeDirPath + "/${x}") homeDirContents;
      in [
        ./home.nix
        nixpkgs-options
        (args: {
          xdg.configFile."nix/inputs/nixpkgs".source = nixpkgs.outPath;
          home = {
            inherit username;
            homeDirectory = "/home/${username}";
            sessionVariables = {
              NIX_PATH = "nixpkgs=${args.config.xdg.configHome}/nix/inputs/nixpkgs$\{NIX_PATH:+:$NIX_PATH}";
            };
          };
          nix.registry.nixpkgs.flake = nixpkgs;
        })
      ] ++ perHost;

      # NixOS configuration imports, including home-manager
      modules = modules-noHM ++ [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.${username}.imports = hm.modules;
        }
      ];

      # Arguments to pass to our NixOS and home-manager configurations
      specialArgs = { inherit inputs outputs nixpkgs-options; };
      extraSpecialArgs = specialArgs;
    in {
      # The actual flake outputs for this host
      nixosConfigurations = {
        "${host}" = nixpkgs.lib.nixosSystem {
          inherit system modules specialArgs;
        };
        "${host}-no-home-manager" = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = modules-noHM;
        };
      };
      homeConfigurations = {
        "${username}@${host}" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs extraSpecialArgs;
          inherit (hm) modules;
        };
      };
    };
  in builtins.foldl' (a: b: lib.attrsets.recursiveUpdate a b) {} [
    (mkHost "nixos-desktop")
    (mkHost "nixos-t480")
  ] // {
    devShells."${system}".default = import ./shell.nix {
      inherit pkgs;
    };
  };

}
