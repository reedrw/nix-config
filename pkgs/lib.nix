self: pkgs:
let
  unstable = pkgs.fromBranch.unstable;
  lib = pkgs.lib;
  # fromLibUnstable :: String -> a
  # check if a function is in unstable
  fromLibUnstable = f: if builtins.hasAttr f lib
    then lib.warn "${f} exists in lib, remove this line from pkgs/lib.nix" lib.${f}
    else unstable.lib.${f};

in
{
  lib = lib.extend (final: prev: lib.pipe [
    "packagesFromDirectoryRecursive"
  ] [
    (map (f: { ${f} = fromLibUnstable f; }))
    (pkgs.mergeAttrs)
  ]);
}
