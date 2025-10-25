self: pkgs:
let
  lib = pkgs.lib;
  pinned = import ./pkgs.nix pkgs;

  # map defaults to top level
  defaults = lib.pipe pinned [
    (lib.filterAttrs (n: v: lib.hasAttr "default" v))
    (lib.mapAttrs (n: v: v.default))
  ];
in { inherit pinned; } // defaults
