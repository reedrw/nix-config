inputs:
self: super:
let
  lib = inputs.nixpkgs.lib;
in
{
  homeConfigurations = lib.mapAttrs (n: v: let
    hostname = builtins.elemAt (lib.splitString "@" n) 1;
    osConfig = if (lib.hasInfix "@" n) then
      super.nixosConfigurations.${hostname}.config
    else {};
  in
    super.homeConfigurations.${n}.extendModules {
      modules = [ { _module.args = { inherit osConfig; }; } ];
    }
  ) super.homeConfigurations;
}
