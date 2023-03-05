let
  sources = import ./nix/sources.nix { };
in
{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: with sources; rec {
    nur = import NUR {
      inherit pkgs;
    };
    nurPkgs = nur.repos.reedrw;
    fromBranch = {
      master = import nixpkgs-master { inherit (pkgs) config system; };
      stable = import nixpkgs-stable { inherit (pkgs) config system; };
    };
  };
}
