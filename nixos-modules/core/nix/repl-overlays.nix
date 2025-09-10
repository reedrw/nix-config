info: final: prev:

{
  self = builtins.getFlake "self";
  pkgs = final.self.nixosConfigurations.${prev.extraInfo.hostName}.pkgs;
  pkgs-unstable = final.pkgs.pkgs-unstable;
  lib = final.pkgs.lib;
}
