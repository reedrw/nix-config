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
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
      substituters = [ "https://reedrw.cachix.org" ];
      trusted-public-keys = [
        "reedrw.cachix.org-1:do9gZInXOYTRPYU+L/x7B90hu1usmnaSFGJl6PN7NC4="
      ];
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
  };
}
