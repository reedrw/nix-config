self: pkgs:
{
  ldp = pkgs.callPackage ./ldp { };
  pin = pkgs.callPackage ./pin { };
  persist-path-manager = pkgs.callPackage ./persist-path-manager { };
}
