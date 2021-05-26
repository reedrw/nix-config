let
  sources = import ./functions/sources.nix { sourcesFile = ./sources.json; };
in
{
  allowUnfree = true;
  allowBroken = true;
  packageOverrides = pkgs: {
    nur = import "${sources.NUR}" {
      inherit pkgs;
    };
  };
}
