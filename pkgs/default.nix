self: pkgs:
{
  gc = pkgs.callPackage ./gc { };
  ldp = pkgs.callPackage ./ldp { };
  pin = pkgs.callPackage ./pin { };
  persist-path-manager = pkgs.callPackage ./persist-path-manager { };
}
