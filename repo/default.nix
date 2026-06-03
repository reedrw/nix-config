{ config, inputs, nixConfig, ... }:

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
      lib.removeSuffix "\n" (builtins.readFile "${root}/nixos-configurations/${hostName}/.flake-path");
  };

  mkUserHomeModules = hostname: users: {
    "${hostname}".userHomeModules = lib.mergeAttrsList (map (user: {
      "${user}" = if lib.hasAttr "${user}@${hostname}" config.ezConfigs.home.users
        then "${user}@${hostname}"
        else user;
    }) users);
  };
in
{
  imports = [
    ./extraEzModules.nix
    inputs.git-hooks-nix.flakeModule
  ];

  ezConfigs = {
    inherit root;

    globalArgs = {
      inherit inputs util;
    };

    home.users = lib.genAttrs [
      "reed"
      "nixos"
      "reed@nixos-desktop"
      "reed@nixos-t400"
      "reed@nixos-t480"
      "reed@nixos-vm"
    ] (n: { nameFunction = _: n; });

    nixos.hosts = lib.mergeAttrsList [
      (mkUserHomeModules "nixos-desktop" [ "reed" ])
      (mkUserHomeModules "nixos-t480"    [ "reed" ])
      (mkUserHomeModules "nixos-t400"    [ "reed" ])
      (mkUserHomeModules "nixos-vm"      [ "reed" ])
      { nixos-iso.userHomeModules = [ "nixos" ]; }
    ];
  };

  perSystem = { pkgs, config, ... }: let
    pkgs' = util.pkgsForSystem inputs.nixpkgs pkgs.stdenv.hostPlatform.system;
  in {
    imports = [
      ./git-hooks.nix
    ];
    packages = pkgs'.myPkgs;
    legacyPackages = { inherit util; };

    devShells.default = (import ../shell.nix {
      pkgs = pkgs';
    }).overrideAttrs (old: {
      shellHook = old.shellHook + ''
        ${config.pre-commit.settings.shellHook}
      '';
      nativeBuildInputs = old.nativeBuildInputs
        ++ config.pre-commit.settings.enabledPackages;
    });
  };
}
