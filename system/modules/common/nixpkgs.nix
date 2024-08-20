{ nixpkgs-options, nixConfig, inputs, pkgs, lib, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

  environment.etc = lib.mapAttrs' (n: v:
    lib.nameValuePair ("nix/inputs/${n}") ({ source = v.outPath; })
  ) inputs;

  nix = {
    package = pkgs.lixVersions.stable;
    settings = {
      auto-optimise-store = true;
      builders-use-substitutes = true;
      experimental-features = [ "flakes" "nix-command" "repl-flake" ];
      extra-substituters = nixConfig.extra-substituters ++ [ ];
      extra-trusted-public-keys = nixConfig.extra-trusted-public-keys ++ [ ];
      keep-derivations = true;
      keep-outputs = true;
      trusted-users = [ "root" "@wheel" ];
      use-xdg-base-directories = true;
    };
    nixPath = lib.mapAttrsToList (n: v: "${n}=/etc/nix/inputs/${n}") inputs;
    registry = lib.mapAttrs (n: v: { flake = v; }) inputs;
  };
}
