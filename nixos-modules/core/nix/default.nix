{ util, rootAbsolute, inputs, pkgs, config, lib, ... }:

{
  # inherit (nixpkgs-options) nixpkgs;
  nixpkgs = {
    inherit (util.nixpkgs-options.nixpkgs) config;
    overlays = util.nixpkgs-options.nixpkgs.overlays ++ [
      (final: prev: { flakePath = rootAbsolute; })
    ];
  };

  # Must be applied, not at flake level, so that it inherits per-system
  # nixpkgs overlays and configuration.
  _module.args = {
    pkgs-unstable = import inputs.unstable {
      inherit (pkgs) config;
      inherit (pkgs.stdenv.hostPlatform) system;
    };
    rootAbsolute = util.rootAbsolute' config.networking.hostName;
  };

  environment.etc = lib.mapAttrs' (n: v:
    lib.nameValuePair "nix/inputs/${n}" <| { source = v.outPath; }
  ) inputs;

  nix = {
    settings = {
      auto-optimise-store = true;
      builders-use-substitutes = true;
      experimental-features = [ "flakes" "nix-command" "pipe-operator" ];
      # check if there's still warning spam in 26.05
      extra-deprecated-features = [
        "broken-string-escape"
        "or-as-identifier"
        "broken-string-indentation"
        "rec-set-dynamic-attrs"
      ];
      extra-substituters = util.nixConfig.extra-substituters ++ [ ];
      extra-trusted-public-keys = util.nixConfig.extra-trusted-public-keys ++ [
        "nixos-desktop:iIOpYCH+cVzPsrJDkYQq/P3SV1dD1eeBe6++C7aY/dc="
      ];
      repl-overlays = [
        (pkgs.writeText "repl-overlay-extrainfo.nix" ''
          info: final: prev: {
            extraInfo.hostName = "${config.networking.hostName}";
          }
        '')
        (pkgs.writeText "repl-overlays.nix" <| lib.readFile ./repl-overlays.nix)
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
