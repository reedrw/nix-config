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
    master = import "${sources.nixpkgs-master}" { };
  };
}
