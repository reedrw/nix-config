self: pkgs:
let
  lib = pkgs.lib;
  pinned = import ./pkgs.nix pkgs;
  # map pinned to top level if top level
  # is not already defined
  final = pinned
    # find packages with only 1 pinned version
    |> lib.filterAttrs (n: v: (lib.count (x: true) (builtins.attrNames v)) == 1)
    # find packages that don't exist in top level
    |> lib.filterAttrs (n: v: !lib.hasAttr n pkgs)
    # map pinned to top level
    |> builtins.mapAttrs (n: v: builtins.elemAt (lib.mapAttrsToList (n2: v2: lib.warn "${n} not found. Using pinned version ${n2}." v2) v) 0)
  ;
in final
