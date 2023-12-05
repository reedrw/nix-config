{ nixpkgs-options, inputs, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

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
      builders-use-substitutes = true
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
    nixPath = [
      "nixpkgs=${inputs.nixpkgs.outPath}"
      "unstable=${inputs.unstable.outPath}"
    ];
    registry = {
      unstable.flake = inputs.unstable;
      nixpkgs.flake = inputs.nixpkgs;
    };
  };
}
