{ NUR ? import ./nixpkgs.nix "NUR"
, master ? import ./nixpkgs.nix "master"
, unstable ? import ./nixpkgs.nix "unstable"
}:

{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: rec {
    nur = import NUR {
      inherit pkgs;
      nurpkgs = pkgs;
    };
    pinned = import ./pin/pkgs.nix pkgs;
    nurPkgs = nur.repos.reedrw;
    fromBranch = {
      master = import master { inherit (pkgs) config system; };
      unstable = import unstable { inherit (pkgs) config system; };
    };
  };
}
