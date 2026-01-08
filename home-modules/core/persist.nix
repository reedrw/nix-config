{ config, osConfig, lib, inputs, ... }:
let
  inherit (osConfig.custom) persistTools persistFiles persistDirectories;

  files = (persistTools.partitionPathsForUser config.home.username persistFiles).right
    |> map (lib.removePrefix config.home.homeDirectory);

  directories = (persistTools.partitionPathsForUser config.home.username persistDirectories).right
    |> map (lib.removePrefix config.home.homeDirectory);
in
{
  # Hack to allow home-manager-only outputs to build in CI
  imports = [
    "${inputs.impermanence}/home-manager.nix"
    {
      home._nixosModuleImported = true;
    }
  ];

  home.persistence.${osConfig.custom.persistDir} = {
    inherit files directories;
  };
}
