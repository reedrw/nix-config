inputs:
self: super:
let
  lib = inputs.nixpkgs.lib;
  machineHmOutputs = lib.filterAttrs (n: v: lib.hasInfix "@" n) super.homeConfigurations;
in
{
  homeConfigurations = lib.mapAttrs (n: v: let
    hostname = builtins.elemAt (lib.splitString "@" n) 1;
    osConfig = super.nixosConfigurations.${hostname}.config;
  in
    super.homeConfigurations.${n}.extendModules {
      modules = [ { _module.args = { inherit osConfig; }; } ];
    }
  ) machineHmOutputs;
}
