{ config, inputs, lib, ... }:
let
  homeManagerUserDirs = config.home-manager.users
  |> lib.mapAttrs (n: v: v.home.homeDirectory);

  partitionPathsForUser = user: paths: lib.partition (x:
    lib.hasPrefix homeManagerUserDirs.${user} x
  ) paths;

  cfg = config.custom;
in
{
  imports = [
    inputs.impermanence.nixosModule
  ];

  options.custom = {
    persistDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Mountpoint for persist subvolume";
    };
    prevDir = lib.mkOption {
      type = lib.types.str;
      default = "/prev";
      description = "Mountpoint for previous subvolume";
    };
    persistJSON = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to persist.json file";
    };
    persistFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if config.custom.persistJSON != null
        then (builtins.fromJSON (lib.readFile config.custom.persistJSON)).files
        else [];
      description = "list of persistent files";
    };
    persistDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if config.custom.persistJSON != null
        then (builtins.fromJSON (lib.readFile config.custom.persistJSON)).directories
        else [];
      description = "list of persistent files";
    };
    persistTools = lib.mkOption {
      type = lib.types.attrs;
      default = {
        inherit homeManagerUserDirs partitionPathsForUser;
      };
      description = "some tools to help with persistence config";
    };
  };

  config = let
    filterUserPaths = paths: lib.foldl' (acc: x:
      (partitionPathsForUser x acc).wrong
    ) paths (lib.attrNames config.home-manager.users);

    nonUserPaths = {
      files = filterUserPaths cfg.persistFiles;
      directories = filterUserPaths cfg.persistDirectories;
    };
  in lib.mkIf (cfg.persistJSON != null) {
    environment.persistence."${config.custom.persistDir}" = {
      hideMounts = true;
      inherit (nonUserPaths) files directories;
    };
  };
}
