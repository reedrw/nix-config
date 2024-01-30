pkgs: let
  lib = pkgs.lib;
  json = lib.importJSON ./pinned.json;
  pinnedVersionToPkg = { rev, sha256 }: import (builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
  }) { inherit (pkgs) system config; };

  mapToPackage = package: a: lib.mapAttrs' (n: v: let
      pinnedPkgs = pinnedVersionToPkg v;
  in lib.nameValuePair
    ("v" + builtins.replaceStrings ["."] ["_"] n)
    ({ pkgs = pinnedPkgs; } // pinnedPkgs."${package}")
  ) a;
in builtins.mapAttrs mapToPackage json
