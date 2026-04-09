pkgs: let
  lib = pkgs.lib;
  json = lib.importJSON ./pinned.json;
  pinnedVersionToPkg = { rev, sha256, ... }: lib.pipe (import (builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
  }) {
    inherit (pkgs.stdenv.hostPlatform) system;
  }) [
    # `config` backwards incompatible after
    # https://github.com/NixOS/nixpkgs/commit/8a5aae22c02b8d0f8306abb1bed314c569c3700f
    (prev: import "${prev.path}" {
      config = pkgs.config // {
        replaceStdenv = _: prev.stdenv;
      };
      inherit (prev.stdenv.hostPlatform) system;
    })
  ];

  mapToPackage = package: a: lib.mapAttrs' (n: v: let
    pinnedPkgs =
      if n == "default"
      then pinnedVersionToPkg a.${v}
      else pinnedVersionToPkg v;
    version =
      if n == "default"
      then n
      else ("v" + builtins.replaceStrings ["."] ["_"] n);
  in lib.nameValuePair
    version ({
      pkgs = pinnedPkgs;
    } // pinnedPkgs."${package}")
  ) a;
in builtins.mapAttrs mapToPackage json
