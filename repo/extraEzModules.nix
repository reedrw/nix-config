{ config, lib, ... }:
let
  directoryToAttrs = dir: builtins.readDir dir
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> lib.filterAttrs (name: value: lib.hasSuffix ".nix" name || (value == "directory" && builtins.pathExists "${dir}/${name}/default.nix"))
    |> lib.mapAttrs' (name: value: lib.nameValuePair (lib.removeSuffix ".nix" name) (import "${dir}/${name}"));

  fromModulesDir = dir: builtins.readDir dir
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> lib.filterAttrs (n: v: v == "directory" && !(lib.hasInfix "@" n || lib.hasSuffix ".nix" n))
    |> lib.mapAttrs (n: v: directoryToAttrs "${dir}/${n}");
in
{
  ezConfigs.home.extraSpecialArgs = config.ezConfigs.globalArgs // {
    ezModules' = fromModulesDir config.ezConfigs.home.modulesDirectory;
  };

  ezConfigs.nixos.specialArgs = config.ezConfigs.globalArgs // {
    ezModules' = fromModulesDir config.ezConfigs.nixos.modulesDirectory;
  };
}
