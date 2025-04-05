info: final: prev:

{
  self = builtins.getFlake "self";
  pkgs = final.self.legacyPackages.${info.currentSystem};
  lib = final.pkgs.lib;
}
