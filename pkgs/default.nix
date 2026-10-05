inputs:
self: pkgs:
let
  myPkgs = {
    gc = pkgs.callPackage ./gc { };
    jdownloader = pkgs.callPackage ./jdownloader { };
    ldp = self.callPackage ./ldp { };
    linuwux-runtime = pkgs.callPackage ./linuwux-runtime { inherit inputs; };
    mountiso = pkgs.callPackage ./mountiso { };
    persist-path-manager = pkgs.callPackage ./persist-path-manager { };
    unscene = self.callPackage ./unscene { };
    update-all = pkgs.callPackage ./update-all { };
    wheel-wizard = pkgs.callPackage ./wheel-wizard { };
    wheel-wizard-unwrapped = pkgs.callPackage ./wheel-wizard/unwrapped.nix { };
    why-diff = pkgs.callPackage ./why-diff { };
    xdcc-dl = pkgs.callPackage ./xdcc-dl { };
    xdcc-tar = pkgs.callPackage ./xdcc-tar { };
  };
in
{
  inherit myPkgs;
} // myPkgs
