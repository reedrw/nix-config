{ inputs, nixConfig, ... }:
let
  versionSuffix = "${builtins.substring 0 8 (inputs.self.lastModifiedDate or inputs.self.lastModified)
                  }_${inputs.self.shortRev or "dirty"}";
  nixpkgs-options.nixpkgs = {
    overlays = [
      (import ../overlays)
      (import ../overlays/branches.nix inputs)
      (import ../overlays/pin/overlay.nix)
      (import ../overlays/alias.nix inputs)
      # (import ../overlays/lib.nix)
      (import ../overlays/functions.nix)
    ];
    config = import ../overlays/config.nix {
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
      nixos-desktop.userHomeModules = {
        reed = "reed@nixos-desktop";
        root = "root";
      };
      nixos-t480.userHomeModules = {
        reed = "reed@nixos-t480";
        root = "root";
      };
      nixos-t400.userHomeModules = {
        reed = "reed@nixos-t400";
        root = "root";
      };
      nixos-vm.userHomeModules = [ "reed" "root" ];
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
