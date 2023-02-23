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
      # TODO: Figure out why the 2 lines below make home-manager evaluation leak memory
      # master = import nixpkgs-master { inherit (pkgs) config overlays system; };
      # stable = import nixpkgs-stable { inherit (pkgs) config overlays system; };
      master = import nixpkgs-master { };
      stable = import nixpkgs-stable { };
    };
  };
}
