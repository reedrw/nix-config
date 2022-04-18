{ config, pkgs, ... }:
let
  sources = import ../../nix/sources.nix { sourcesFile = ../../nix/sources.json; };
in
{
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    packageOverrides = pkgs: {
      nur = import sources.NUR {
        inherit pkgs;
      };
    };
  };

  nix = {
    autoOptimiseStore = true;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
    trustedUsers = [ "root" "@wheel" ];

    binaryCaches = [
      "https://reedrw.cachix.org"
    ];
    binaryCachePublicKeys = [
      "reedrw.cachix.org-1:do9gZInXOYTRPYU+L/x7B90hu1usmnaSFGJl6PN7NC4="
    ];
  };
}
