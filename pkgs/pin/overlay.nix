_: pkgs:
let
  inherit (pkgs) lib;
  pinned = import ./pkgs.nix pkgs;

  # map defaults to top level
  defaults = lib.pipe pinned [
    (lib.filterAttrs (_: v: lib.hasAttr "default" v))
    (lib.mapAttrs (_: v: v.default))
  ];
in { inherit pinned; } // defaults
