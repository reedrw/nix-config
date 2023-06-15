{ NUR ? import ./nixpkgs.nix "NUR"
, master ? import ./nixpkgs.nix "master"
, stable ? import ./nixpkgs.nix "stable"
}:

{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: rec {
    nur = import NUR {
      inherit pkgs;
      nurpkgs = pkgs;
    };
    nurPkgs = nur.repos.reedrw;
    fromBranch = {
      master = import master { inherit (pkgs) config system; };
      stable = import stable { inherit (pkgs) config system; };
    };
  };
}
