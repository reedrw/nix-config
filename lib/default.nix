{ inputs, nixConfig, ... }:

let
  nixpkgs-options.nixpkgs = {
    overlays = [
      (import ../pkgs)
      (import ../pkgs/branches.nix inputs)
      (import ../pkgs/pin/overlay.nix)
      (import ../pkgs/alias.nix inputs)
      (import ../pkgs/lib.nix)
      (import ../pkgs/functions.nix)
    ];
    config = import ../pkgs/config.nix {
      inherit inputs;
    };
  };
in
rec {

  # pgksForSystem :: String -> AttrSet
  ########################################
  # Takes a system name as argument and returns a nixpkgs set for that system.
  pkgsForSystem = src: system:
    import src (nixpkgs-options.nixpkgs // {
        inherit system;
    });

  system = "x86_64-linux";
  pkgs = pkgsForSystem inputs.nixpkgs system;
  pkgs-unstable = pkgsForSystem inputs.unstable system;
  lib = pkgs.lib;

  versionSuffix = "${builtins.substring 0 8 (inputs.self.lastModifiedDate or inputs.self.lastModified)
	          }_${inputs.self.shortRev or "dirty"}";

  # mkModulesFromDir :: AttrSet -> [AttrSet -> AttrSet]
  ########################################
  # WARNING: VERY CURSED CODE AHEAD
  #
  # Takes a directory name as argument and returns a NixOS module for that
  # directory. The module will be named after the directory.
  #
  # Available arguments:
  # - dir (Path): The directory to create a module from
  # - default (Boolean): Whether the modules in this directory should be enabled by default
  # - moduleName (String): The attribute name under which the option should be created,
  #   defaults to the base name of the directory
  #
  # Example:
  # mkModuleFromDir { dir = ./common; }
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
  mkModulesFromDir = {
    dir,
    default ? true,
    moduleName ? builtins.baseNameOf dir
  }: let
    # Convert the directory structor into an attribute set
    dirSet = let
      dirSet = inputs.haumea.lib.load {
        src = dir;
        loader = inputs.haumea.lib.loaders.verbatim;
      };
    in builtins.mapAttrs (name: value:
      # if there is a default.nix file in the directory, use it as the default value
      if (builtins.isAttrs value && builtins.hasAttr "default" value)
      then value.default
      else value
    ) dirSet;

    # For each attribute of dirSet, create a NixOS option
    # which, when enabled, will import the attribute's value.
  in lib.mapAttrsToList (name: value:
    { config, pkgs, ... } @ args:
    let
      cfg = config.${moduleName}.${name};
      module = importAppropriately value;

      # Recursively import the module and its dependencies
      # this allows submodules to be disabled if the generated
      # NixOS module is not enabled
      conditionalImportPathsRecursive = map (x:
        let
          module = importAppropriately x;
        in { ... }: {
          config = lib.mkIf cfg.enable (getConfig module);
          imports = conditionalImportPathsRecursive (module.imports or []);
          options = module.options or {};
        }
      );
      getConfig = module: (module.config or {}) // (lib.removeAttrs module [ "config" "imports" "options" "_file"]);
      importAppropriately = module: if (builtins.isPath module || builtins.isString module)
        then importAppropriately (import module)
        else if builtins.isFunction module
          then module args
          # otherwise, assume it's a set
          else module;
    in
    {
      config = lib.mkIf cfg.enable (getConfig module);
      imports = conditionalImportPathsRecursive (module.imports or []);
      options = {
        ${moduleName}.${name}.enable = lib.mkOption {
          inherit default;
          type = lib.types.bool;
          description = "Whether to enable ${moduleName}.${name}";
        };
      } // (module.options or {});
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
      userModules = mkModulesFromDir {
        default = false;
        dir =  ../system/modules/myUsers;
      };
      commonModules = mkModulesFromDir { dir = ../system/modules/common; };
      customModules = lib.listDirectory   ../system/modules/custom;
    in [
      ../system/${host}/configuration.nix
      ../system/${host}/hardware-configuration.nix
      inputs.impermanence.nixosModule
      (_: { networking.hostName = "${host}"; })
    ] ++ commonModules
      ++ userModules
      ++ customModules;

    # Home-manager configuration imports
    hm.modules = let
      # Each host has a directory for home-manager config in ./system/${host}/home.
      # Any .nix files in that directory will be imported as part of the home-manager
      # configuration for that host.
      perHost = lib.listDirectory ../system/${host}/home;
      hmCommon = mkModulesFromDir {
        dir = ../home;
        moduleName = "common";
      };
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
          extraSpecialArgs = specialArgs // { asNixosModule = true; };
          useGlobalPkgs = true;
          backupFileExtension = "backup";
        };
      }
    ];

    # Arguments to pass to our NixOS and home-manager configurations
    specialArgs = { inherit inputs nixpkgs-options nixConfig pkgs-unstable versionSuffix; };
  in {
    # The actual flake outputs for this host
    nixosConfigurations = {
      "${host}" = inputs.nixpkgs.lib.nixosSystem {
        inherit system lib;
        modules = modulesWithHM;
        specialArgs = specialArgs // { hm = true; };
      };
      "${host}-no-home-manager" = inputs.nixpkgs.lib.nixosSystem {
        inherit system modules lib;
        specialArgs = specialArgs // { hm = false; };
      };
    };
    homeConfigurations = let
      extraSpecialArgs = specialArgs // {
        # When used as a NixOS module, home-manager sets the parameter `osConfig` to the NixOS
        # configuration that is importing it. We need to set this parameter manually when
        # building a standalone home-manager generation.
        osConfig = inputs.self.nixosConfigurations."${host}".config;
        asNixosModule = false;
      };
    in {
      "${username}@${host}" = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs extraSpecialArgs;
        inherit (hm) modules;
      };
    };
  };

  mkHosts = hosts: lib.mergeAttrsListRecursive (map mkHost hosts);
}
