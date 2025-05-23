{ nixpkgs-options, nixConfig, inputs, pkgs, lib, ... }:

{
  inherit (nixpkgs-options) nixpkgs;

  _module.args.pkgs-unstable = import inputs.unstable {
    inherit (pkgs) system config;
  };

  environment.etc = lib.mapAttrs' (n: v:
    lib.nameValuePair ("nix/inputs/${n}") ({ source = v.outPath; })
  ) inputs;

  nix = {
    settings = {
      auto-optimise-store = true;
      builders-use-substitutes = true;
      experimental-features = [ "flakes" "nix-command" "pipe-operator" ];
      extra-substituters = nixConfig.extra-substituters ++ [ ];
      extra-trusted-public-keys = nixConfig.extra-trusted-public-keys ++ [
        "nixos-desktop:iIOpYCH+cVzPsrJDkYQq/P3SV1dD1eeBe6++C7aY/dc="
      ];
      repl-overlays = [ "${pkgs.flakePath}/nixos-modules/core/nix/repl-overlays.nix" ];
      keep-derivations = true;
      keep-outputs = true;
      trusted-users = [ "root" "@wheel" ];
      use-xdg-base-directories = true;
    };
    nixPath = lib.mapAttrsToList (n: v: "${n}=flake:${n}") inputs;
    registry = lib.mapAttrs (n: v: { flake = v; }) inputs;
  };
}
