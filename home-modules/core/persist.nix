{ config, osConfig, lib, inputs, ... }:
let
  inherit (osConfig.custom) copyPersistPaths persistTools persistFiles persistDirectories;

  files = (persistTools.partitionPathsForUser config.home.username persistFiles).right
    |> map (lib.removePrefix config.home.homeDirectory);

  directories = (persistTools.partitionPathsForUser config.home.username persistDirectories).right
  |> map (lib.removePrefix config.home.homeDirectory);

  cfg = config.custom.persistence;
in
{
  # Hack to allow home-manager-only outputs to build in CI
  imports = [
    "${inputs.impermanence}/home-manager.nix"
    {
      home._nixosModuleImported = true;
    }
  ];

  options.custom.persistence = {
    directories = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [];
      description = "Directories to persist";
    };
    files = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [];
      description = "Files to persist";
    };
  };

  config = {
    home.persistence.${osConfig.custom.persistDir} = lib.foldl' (acc: x: {
      files = (acc.files or []) ++ x.files;
      directories = (acc.directories or []) ++ x.directories;
    }) {} [
      {
        inherit files directories;
      }
      (lib.optionalAttrs copyPersistPaths {
        inherit (cfg) files directories;
      })
    ];
  };
}
