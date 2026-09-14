self: pkgs:
let
  myPkgs = {
    gc = pkgs.callPackage ./gc { };
    jdownloader = pkgs.callPackage ./jdownloader { };
    ldp = self.callPackage ./ldp { };
    mountiso = pkgs.callPackage ./mountiso { };
    persist-path-manager = pkgs.callPackage ./persist-path-manager { };
    unscene = self.callPackage ./unscene { };
    update-all = pkgs.callPackage ./update-all { };
    why-diff = pkgs.callPackage ./why-diff { };
    wheel-wizard-unwrapped = pkgs.callPackage ./wheel-wizard/unwrapped.nix { };
    wheel-wizard = pkgs.callPackage ./wheel-wizard { };
    xdcc-dl = pkgs.callPackage ./xdcc-dl { };
    xdcc-tar = pkgs.callPackage ./xdcc-tar { };
  };
in
{
  inherit myPkgs;
} // myPkgs
