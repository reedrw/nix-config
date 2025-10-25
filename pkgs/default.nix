self: pkgs:
let
  myPkgs = {
    gc = pkgs.callPackage ./gc { };
    jdownloader = pkgs.callPackage ./jdownloader { };
    ldp = self.callPackage ./ldp { };
    pin = pkgs.callPackage ./pin { };
    persist-path-manager = pkgs.callPackage ./persist-path-manager { };
    update-all = pkgs.callPackage ./update-all { };
    wheel-wizard = pkgs.callPackage ./wheel-wizard { };
  };
in
{
  inherit myPkgs;
} // myPkgs
