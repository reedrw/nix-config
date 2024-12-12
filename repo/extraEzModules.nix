{ config, inputs, ... }:
let
  fromModulesDir = src: inputs.haumea.lib.load {
    inherit src;
    loader = inputs.haumea.lib.loaders.path;
  };
in
{
  ezConfigs.home.extraSpecialArgs = config.ezConfigs.globalArgs // {
    ezModules' = fromModulesDir config.ezConfigs.home.modulesDirectory;
  };

  ezConfigs.nixos.specialArgs = config.ezConfigs.globalArgs // {
    ezModules' = fromModulesDir config.ezConfigs.nixos.modulesDirectory;
  };
}
