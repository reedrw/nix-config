self: pkgs:
let
  lib = pkgs.lib;
  pinned = pkgs.pinned;

  # map defaults to top level
  defaults = pinned
    |> lib.filterAttrs (n: v: lib.hasAttr "default" v)
    |> lib.mapAttrs (n: v: v.default);
in defaults
