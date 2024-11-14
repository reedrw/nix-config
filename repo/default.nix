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
        spicypillow = "spicypillow";
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
    legacyPackages = pkgsForSystem inputs.nixpkgs pkgs.system;

    devShells.default = import ../shell.nix {
      pkgs = legacyPackages;
    };
  };
}
