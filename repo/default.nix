{ inputs, nixConfig, ... }:
let
  versionSuffix = "${builtins.substring 0 8 (inputs.self.lastModifiedDate or inputs.self.lastModified)
                  }_${inputs.self.shortRev or "dirty"}";

  nixpkgs-options.nixpkgs = {
    overlays = import ../pkgs/overlays.nix {
      flake = inputs.self;
    };
    config = import ../pkgs/config.nix {
      flake = inputs.self;
    };
  };

  pkgsForSystem = src: system:
    import src (nixpkgs-options.nixpkgs // {
        inherit system;
    });

  lib = inputs.nixpkgs.lib;
in
{
  imports = [
    ./extraEzModules.nix
  ];

  ezConfigs = {
    root = ../.;

    globalArgs = {
      inherit inputs nixpkgs-options nixConfig versionSuffix;
    };

    home.users = lib.genAttrs [
      "root"
      "reed"
      "reed@nixos-desktop"
      "reed@nixos-t400"
      "reed@nixos-t480"
      "reed@nixos-vm"
      "reed@nixos-iso"
    ] (n: {
      nameFunction = _: n;
      passInOsConfig = false;
    });

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
      nixos-vm.userHomeModules = {
        reed = "reed@nixos-vm";
        root = "root";
      };
      nixos-iso.userHomeModules = {
        reed = "reed@nixos-iso";
        root = "root";
      };
    };
  };

  flake = {
    inherit pkgsForSystem;
  };

  perSystem = { pkgs, lib, inputs', ... }: let
    pkgs' = pkgsForSystem inputs.nixpkgs pkgs.system;
  in {
    packages = pkgs'.myPkgs;

    devShells.default = import ../shell.nix {
      pkgs = pkgs';
    };
  };
}
