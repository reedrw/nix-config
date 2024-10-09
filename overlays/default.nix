self: pkgs:
{
  flakePath = "/home/reed/.config/nixpkgs";
  gc = pkgs.callPackage ./gc { };
  ldp = self.callPackage ./ldp { };
  pin = pkgs.callPackage ./pin { };
  persist-path-manager = pkgs.callPackage ./persist-path-manager { };
}
