info: final: prev:

{
  self = builtins.getFlake "self";
  pkgs = final.self.pkgsForSystem final.self.inputs.nixpkgs info.currentSystem;
  lib = final.pkgs.lib;
}
