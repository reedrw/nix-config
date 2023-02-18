let
  sources = import ./nix/sources.nix { };
in
{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: with sources; {
    nur = import NUR {
      inherit pkgs;
    };
    fromBranch = {
      master = import nixpkgs-master { };
      stable = import nixpkgs-stable { };
    };
  };
}
