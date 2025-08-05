{ nixpkgs-options, nixConfig, root, rootAbsolute, inputs, pkgs, config, lib, ... }:

{
  # inherit (nixpkgs-options) nixpkgs;
  nixpkgs = {
    inherit (nixpkgs-options.nixpkgs) config;
    overlays = nixpkgs-options.nixpkgs.overlays ++ [
      (final: prev: { flakePath = rootAbsolute; })
    ];
  };

  # Must be applied, not at flake level, so that it inherits per-system
  # nixpkgs overlays and configuration.
  _module.args.pkgs-unstable = import inputs.unstable {
    inherit (pkgs) system config;
  };

  _module.args.rootAbsolute =
    builtins.readFile "${root}/nixos-configurations/${config.networking.hostName}/.flake-path"
      |> lib.removeSuffix "\n";

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
      repl-overlays = [
        (pkgs.writeText "repl-overlay-extrainfo.nix" ''
          info: final: prev: {
            extraInfo.hostName = "${config.networking.hostName}";
          }
        '')
        ./repl-overlays.nix
      ];
      keep-derivations = true;
      keep-outputs = true;
      trusted-users = [ "root" "@wheel" ];
      use-xdg-base-directories = true;
    };
    nixPath = lib.mapAttrsToList (n: v: "${n}=flake:${n}") inputs;
    registry = lib.mapAttrs (n: v: { flake = v; }) inputs;
  };
}
