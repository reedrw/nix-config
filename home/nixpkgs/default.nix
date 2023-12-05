{ nixpkgs-options, inputs,... }:

{
  inherit (nixpkgs-options) nixpkgs;

  home.sessionVariables = {
    NIX_PATH = "unstable=${inputs.unstable.outPath}:nixpkgs=${inputs.nixpkgs.outPath}$\{NIX_PATH:+:$NIX_PATH}";
  };

  nix.registry = {
    nixpkgs.flake = inputs.nixpkgs;
    unstable.flake = inputs.unstable;
  };
}
