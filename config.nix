let
  sources = import ./nix/sources.nix { };
in
{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: {
    nur = import "${sources.NUR}" {
      inherit pkgs;
    };
    fromBranch = {
      master = import "${sources.nixpkgs-master}" { };
      stable = import "${sources.nixpkgs-stable}" { };
      staging-next = import "${sources.nixpkgs-staging-next}" { };
    };
  };
}
