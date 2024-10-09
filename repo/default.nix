{ inputs, nixConfig, ... }:
let
  versionSuffix = "${builtins.substring 0 8 (inputs.self.lastModifiedDate or inputs.self.lastModified)
                  }_${inputs.self.shortRev or "dirty"}";
  nixpkgs-options.nixpkgs = {
    overlays = [
      (import ../pkgs)
      (import ../pkgs/branches.nix inputs)
      (import ../pkgs/pin/overlay.nix)
      (import ../pkgs/alias.nix inputs)
      # (import ../pkgs/lib.nix)
      (import ../pkgs/functions.nix)
    ];
    config = import ../pkgs/config.nix {
      inherit inputs;
    };
  };

  pkgsForSystem = src: system:
    import src (nixpkgs-options.nixpkgs // {
        inherit system;
    });

  pkgs = pkgsForSystem inputs.nixpkgs "x86_64-linux";
  lib = pkgs.lib;

in
{
  ezConfigs = {
    globalArgs = {
      inherit inputs nixpkgs-options nixConfig versionSuffix;
    };

    # home.users."reed".nameFunction = (_: "reed");
    # home.users."reed@nixos-desktop".nameFunction = (_: "reed@nixos-desktop");
    # home.users."reed@nixos-t480".nameFunction = (_: "reed@nixos-t480");
    home.users = builtins.readDir ../home-configurations
      |> builtins.attrNames
      |> map (lib.removeSuffix ".nix")
      |> map (configName: { "${configName}".nameFunction = (_: configName); } )
      |> lib.mergeAttrsList;

    nixos.hosts = {
      nixos-desktop.userHomeModules = { reed = "reed@nixos-desktop"; };
      nixos-t480.userHomeModules = { reed = "reed@nixos-t480"; };
      nixos-t400.userHomeModules = { reed = "reed@nixos-t400"; };
      nixos-vm.userHomeModules = [ "reed" ];
    };
  };

  perSystem = { pkgs, inputs', ... }: rec {
    legacyPackages = (pkgsForSystem inputs.nixpkgs pkgs.system) // {
      pkgs-unstable = pkgsForSystem inputs.unstable pkgs.system;
    };

    devShells.default = import ../shell.nix {
      pkgs = legacyPackages;
    };
  };
}
