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

  system = "x86_64-linux";
  pkgs = pkgsForSystem system;
  lib = pkgs.lib;

  # mkModuleFromDir :: String -> [AttrSet -> AttrSet]
  ########################################
  # Takes a directory name as argument and returns a NixOS module for that
  # directory. The module will be named after the directory.
  #
  # Example:
  # mkModuleFromDir "common"
  #
  # common/
  # - bluetooth.nix
  # - neworking.nix
  # - sound.nix
  #
  # Will enable the following NixOS options
  # {
  #   common.bluetooth.enable = true;
  #   common.networking.enable = true;
  #   common.sound.enable = true;
  # }
  #
  mkModuleFromDir = dir:
  let
    # The module name is the basename of the directory
    moduleName = builtins.baseNameOf dir;
    # Convert the directory structor into an attribute set
    dirSet = inputs.haumea.lib.load {
      src = dir;
      loader = inputs.haumea.lib.loaders.verbatim;
    };
    # For each attribute of dirSet, create a NixOS option
    # which, when enabled, will import the attribute's value.
  in lib.mapAttrsToList (name: value:
    { config, pkgs, ... } @ args:
    let
      cfg = config.${moduleName}.${name};
    in
    {
      options.${moduleName}.${name}.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable ${moduleName}.${name}";
      };

      config = lib.mkIf cfg.enable (value args);
    }
  ) dirSet;

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
    modules-noHM = let
      commonModules = mkModuleFromDir ../system/modules/common;
      customModules = pkgs.listDirectory ../system/modules/custom;
    in [
      (../. + "/system/${host}/configuration.nix")
      inputs.impermanence.nixosModule
      nixpkgs-options
      {
        environment.etc."nix/inputs/nixpkgs".source = inputs.nixpkgs.outPath;
        environment.etc."nix/inputs/unstable".source = inputs.unstable.outPath;
        nix.registry.nixpkgs.flake = inputs.nixpkgs;
        nix.registry.unstable.flake = inputs.unstable;
        nix.nixPath = [
          "nixpkgs=/etc/nix/inputs/nixpkgs"
          "unstable=/etc/nix/inputs/unstable"
        ];
      }
    ] ++ commonModules ++ customModules;

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
        xdg.configFile."nix/inputs/unstable".source = inputs.unstable.outPath;
        home = {
          inherit username;
          homeDirectory = "/home/${username}";
          sessionVariables = {
            NIX_PATH = "unstable=${args.config.xdg.configHome}/nix/inputs/unstable:nixpkgs=${args.config.xdg.configHome}/nix/inputs/nixpkgs$\{NIX_PATH:+:$NIX_PATH}";
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
        inherit system modules;
        specialArgs = specialArgs // { hm = true; };
      };
      "${host}-no-home-manager" = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = specialArgs // { hm = false; };
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

  mkHosts = hosts: pkgs.mergeAttrs (map mkHost hosts);
}
