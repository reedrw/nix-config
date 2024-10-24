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

in
{
  ezConfigs = {
    root = ../.;

    globalArgs = {
      inherit inputs nixpkgs-options nixConfig versionSuffix;
    };

    home.users = {
      "root".nameFunction = (_: "root");
      "reed".nameFunction = (_: "reed");
      "reed@nixos-desktop".nameFunction = (_: "reed@nixos-desktop");
      "reed@nixos-t480".nameFunction = (_: "reed@nixos-t480");
      "reed@nixos-t400".nameFunction = (_: "reed@nixos-t400");
    };

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
