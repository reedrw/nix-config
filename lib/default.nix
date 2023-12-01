{ inputs, outputs, self, ... }:

let
  nixpkgs-options.nixpkgs = {
    overlays = [ (import ../pkgs) ];
    config = import ../pkgs/config.nix {
      inherit (inputs) NUR master unstable;
    };
  };
in
rec {

  # pgksForSystem :: String -> AttrSet
  ########################################
  # Takes a system name as argument and returns a nixpkgs set for that system.
  pkgsForSystem = system:
    import inputs.nixpkgs (nixpkgs-options.nixpkgs // {
        inherit system;
    });

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

    system = "x86_64-linux";
    pkgs = pkgsForSystem system;

    # NixOS configuration imports, minus home-manager
    modules-noHM = let
      commonImports = pkgs.listDirectory ../system/common;
      moduleImports = pkgs.listDirectory ../system/modules;
    in [
      (../. + "/system/${host}/configuration.nix")
      inputs.impermanence.nixosModule
      nixpkgs-options
      {
        environment.etc."nix/inputs/nixpkgs".source = inputs.nixpkgs.outPath;
        nix.registry.nixpkgs.flake = inputs.nixpkgs;
        nix.nixPath = ["nixpkgs=/etc/nix/inputs/nixpkgs"];
      }
    ] ++ commonImports ++ moduleImports;

    # Home-manager configuration imports
    hm.modules = let
      # Each host has a directory for home-manager config in ./system/${host}/home.
      # Any .nix files in that directory will be imported as part of the home-manager
      # configuration for that host.
      perHost = pkgs.listDirectory (../. + "/system/${host}/home");
      hmCommon = pkgs.listDirectory ../home;
    in [
      ../home.nix
      nixpkgs-options
      (args: {
        xdg.configFile."nix/inputs/nixpkgs".source = inputs.nixpkgs.outPath;
        home = {
          inherit username;
          homeDirectory = "/home/${username}";
          sessionVariables = {
            NIX_PATH = "nixpkgs=${args.config.xdg.configHome}/nix/inputs/nixpkgs$\{NIX_PATH:+:$NIX_PATH}";
          };
        };
        nix.registry.nixpkgs.flake = inputs.nixpkgs;
      })
    ] ++ perHost ++ hmCommon;

    # NixOS configuration imports, including home-manager
    modules = modules-noHM ++ [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.users.${username}.imports = hm.modules;
      }
    ];

    # Arguments to pass to our NixOS and home-manager configurations
    specialArgs = { inherit inputs outputs nixpkgs-options; };
  in {
    # The actual flake outputs for this host
    nixosConfigurations = {
      "${host}" = inputs.nixpkgs.lib.nixosSystem {
        inherit system modules specialArgs;
      };
      "${host}-no-home-manager" = inputs.nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = modules-noHM;
      };
    };
    homeConfigurations = let
      extraSpecialArgs = specialArgs // {
        # When used as a NixOS module, home-manager sets the parameter `osConfig` to the NixOS
        # configuration that is importing it. We need to set this parameter manually when
        # building a standalone home-manager generation.
        osConfig = self.nixosConfigurations."${host}".config;
      };
    in {
      "${username}@${host}" = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs extraSpecialArgs;
        inherit (hm) modules;
      };
    };
  };
}
