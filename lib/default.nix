{ inputs, nixConfig, ... }:

let
  nixpkgs-options.nixpkgs = {
    overlays = [
      (import ../pkgs)
      (import ../pkgs/pin/overlay.nix)
      (import ../pkgs/functions.nix)
      (import ../pkgs/alias.nix)
    ];
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

  # mkModuleFromDir :: Bool -> String -> [AttrSet -> AttrSet]
  ########################################
  # Takes a directory name as argument and returns a NixOS module for that
  # directory. The module will be named after the directory.
  #
  # Example:
  # mkModuleFromDir true "common"
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
  mkModuleFromDir = default: dir:
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
      imports = lib.filterAttrs (n: v: n == "imports") (value args);
    in
    {
      imports = imports.imports or [];

      options.${moduleName}.${name}.enable = lib.mkOption {
        inherit default;
        type = lib.types.bool;
        description = "Whether to enable ${moduleName}.${name}";
      };

      config = lib.mkIf cfg.enable (lib.filterAttrs (n: v: n != "imports") (value args));
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
  mkHost = host:
  let
    # For now, repo is only set up for 1 home-manager user
    username = "reed";

    # NixOS configuration imports, minus home-manager
    modules = let
      userModules = mkModuleFromDir false  ../system/modules/myUsers;
      commonModules = mkModuleFromDir true ../system/modules/common;
      customModules = pkgs.listDirectory   ../system/modules/custom;
    in [
      ../system/${host}/configuration.nix
      ../system/${host}/hardware-configuration.nix
      inputs.impermanence.nixosModule
    ] ++ commonModules
      ++ userModules
      ++ customModules;

    # Home-manager configuration imports
    hm.modules = let
      # Each host has a directory for home-manager config in ./system/${host}/home.
      # Any .nix files in that directory will be imported as part of the home-manager
      # configuration for that host.
      perHost = pkgs.listDirectory ../system/${host}/home;
      hmCommon = pkgs.listDirectory ../home;
    in [
      ../home.nix
      (_:{ home = {
        inherit username;
        homeDirectory = "/home/${username}";
      };})
    ] ++ perHost ++ hmCommon;

    # NixOS configuration imports, including home-manager
    modulesWithHM = modules ++ [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          users.${username}.imports = hm.modules;
          extraSpecialArgs = specialArgs;
          useGlobalPkgs = true;
          backupFileExtension = "backup";
        };
      }
    ];

    # Arguments to pass to our NixOS and home-manager configurations
    specialArgs = { inherit inputs nixpkgs-options nixConfig; };
  in {
    # The actual flake outputs for this host
    nixosConfigurations = {
      "${host}" = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modulesWithHM;
        specialArgs = specialArgs // { hm = true; };
      };
      "${host}-no-home-manager" = inputs.nixpkgs.lib.nixosSystem {
        inherit system modules;
        specialArgs = specialArgs // { hm = false; };
      };
    };
    homeConfigurations = let
      extraSpecialArgs = specialArgs // {
        # When used as a NixOS module, home-manager sets the parameter `osConfig` to the NixOS
        # configuration that is importing it. We need to set this parameter manually when
        # building a standalone home-manager generation.
        osConfig = inputs.self.nixosConfigurations."${host}".config;
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
