{ nixpkgs-options, nixConfig, inputs, pkgs, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

  nix = {
    package = pkgs.lixVersions.stable;
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
      # inherit (nixConfig) extra-substituters extra-trusted-public-keys;
      extra-substituters = nixConfig.extra-substituters ++ [ ];
      extra-trusted-public-keys = nixConfig.extra-trusted-public-keys ++ [ ];
    };
    extraOptions = ''
      builders-use-substitutes = true
      keep-derivations = true
      keep-outputs = true
      use-xdg-base-directories = true
      experimental-features = flakes nix-command repl-flake
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
