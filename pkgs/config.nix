{ NUR ? import ./nixpkgs.nix "NUR"
, unstable ? import ./nixpkgs.nix "unstable"
}:

{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: (rec {
    nur = import NUR {
      inherit pkgs;
      nurpkgs = pkgs;
    };
    pinned = import ./pin/pkgs.nix pkgs;
    nurPkgs = nur.repos.reedrw;
    fromBranch = {
      unstable = import unstable { inherit (pkgs) config system; };
    };
  }) // import ./pin/overlay.nix pkgs pkgs;
}
