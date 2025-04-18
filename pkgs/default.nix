self: pkgs:
let
  myPkgs = {
    flakePath = "/home/reed/files/nix-config";
    gc = pkgs.callPackage ./gc { };
    ldp = self.callPackage ./ldp { };
    pin = pkgs.callPackage ./pin { };
    persist-path-manager = pkgs.callPackage ./persist-path-manager { };
    WheelWizard = pkgs.callPackage ./WheelWizard { };
  };
in
{
  inherit myPkgs;
} // myPkgs
