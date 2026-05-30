info: final: prev:

{
  self = builtins.getFlake "self";
  pkgs = final.self.nixosConfigurations.${prev.extraInfo.hostName}.pkgs;
  lib = final.pkgs.lib;
  config = final.self.nixosConfigurations.${prev.extraInfo.hostName}.config;
}
