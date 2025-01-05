self: pkgs:
{
  flakePath = "/home/reed/files/nix-config";
  gc = pkgs.callPackage ./gc { };
  keybind = pkgs.callPackage ./keybind { };
  ldp = self.callPackage ./ldp { };
  pin = pkgs.callPackage ./pin { };
  persist-path-manager = pkgs.callPackage ./persist-path-manager { };
}
