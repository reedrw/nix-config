pkgs: let
  lib = pkgs.lib;
  json = lib.importJSON ./pinned.json;
  pinnedVersionToPkg = {rev, sha256}: import (builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
  }) { inherit (pkgs) system config; };

  mapToPackage = package: a: lib.mapAttrs' (n: v: lib.nameValuePair
    ("v" + (builtins.replaceStrings ["."] ["_"] n))
    (pinnedVersionToPkg v)."${package}"
  ) a;
in (builtins.mapAttrs (n: v: (mapToPackage n v))) json
