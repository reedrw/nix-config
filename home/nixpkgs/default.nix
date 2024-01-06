{ nixpkgs-options, nixConfig, inputs, osConfig, lib, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

  home.sessionVariables = {
    NIX_PATH = "unstable=${inputs.unstable.outPath}:nixpkgs=${inputs.nixpkgs.outPath}$\{NIX_PATH:+:$NIX_PATH}";
  };

  nix = {
    package = lib.mkDefault osConfig.nix.package;

    registry = {
      nixpkgs.flake = inputs.nixpkgs;
      unstable.flake = inputs.unstable;
    };

    settings = {
      inherit (nixConfig) extra-substituters extra-trusted-public-keys;
    };
  };

}
