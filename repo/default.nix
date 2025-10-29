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

  root = ../.;

  lib = inputs.nixpkgs.lib;

  util = { inherit nixpkgs-options nixConfig versionSuffix root; } // {
    importFlake = path: (import inputs.flake-compat {
      src = path;
      useBuiltinsFetchTree = true;
    }).defaultNix;

    pkgsForSystem = src: system:
      import src (nixpkgs-options.nixpkgs // {
          inherit system;
      });

    rootAbsolute' = hostName:
      builtins.readFile "${root}/nixos-configurations/${hostName}/.flake-path"
        |> lib.removeSuffix "\n";

  };
in
{
  imports = [
    ./extraEzModules.nix
  ];

  ezConfigs = {
    inherit root;

    globalArgs = {
      inherit inputs util;
    };

    home.users = lib.genAttrs [
      "root"
      "reed"
      "nixos"
      "reed@nixos-desktop"
      "reed@nixos-t400"
      "reed@nixos-t480"
      "reed@nixos-vm"
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
        nixos = "nixos";
        root = "root";
      };
    };
  };

  perSystem = { pkgs, lib, ... }: let
    pkgs' = util.pkgsForSystem inputs.nixpkgs pkgs.system;
  in {
    packages = pkgs'.myPkgs;
    legacyPackages = { inherit util; };

    devShells.default = import ../shell.nix {
      pkgs = pkgs';
    };
  };
}
