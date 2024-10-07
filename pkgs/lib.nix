self: pkgs:
let
  inherit (pkgs) pkgs-unstable;
  lib = pkgs.lib;
  # fromLibUnstable :: String -> a
  # check if a function is in unstable
  fromLibUnstable = f: if builtins.hasAttr f lib
    then lib.warn "${f} exists in lib, remove this line from pkgs/lib.nix" lib.${f}
    else pkgs-unstable.lib.${f};

in
{
  lib = (lib.extend (final: prev: {
    # {{{ Custom lib extensions

    # listDirectory :: Path -> [Path]
    ########################################
    # Given a path to a directory, return a list of everything in that directory
    # relative to the calling nix file.
    listDirectory = path:
      builtins.map (x: path + "/${x}") (builtins.attrNames (builtins.readDir path));

    # mergeAttrsListRecursive :: [AttrSet] -> AttrSet
    ########################################
    # Takes a list of attribute sets and merges them into one using lib.recursiveUpdate
    # Ex.
    # mergeAttrsListRecursive [
    #   { a = 1; b = 2; }
    #   { b = 3; c = 4; }
    # ]
    #
    # Returns:
    # { a = 1; b = 3; c = 4; }
    mergeAttrsListRecursive = attrs: lib.foldl' lib.recursiveUpdate {} attrs;

    # optionalApply :: Bool -> (a -> b) -> a -> b
    #############################################
    # Given a boolean, a function, and a value, apply the function to the value if the boolean is true.
    # Ex.
    # optionalApply true (x: x + 1) 1
    #
    # Returns:
    # 2
    optionalApply = bool: f: x:
      if bool then f x else x;

    # partitionAttrs :: (String -> a -> Bool) -> AttrSet -> AttrSet
    #################################################################
    # Given a predicate function and an attribute set, partition the attribute set into two
    # attribute sets, one containing the attributes that satisfy the predicate and one containing
    # the attributes that do not.
    # Ex.
    # partitionAttrs (n: v: n == "foo") { foo = 1; bar = 2; }
    #
    # Returns:
    # { right = { foo = 1; }; wrong = { bar = 2; }; }
    partitionAttrs = predicate: attrs: {
      right = lib.filterAttrs predicate attrs;
      wrong = lib.filterAttrs (n: v: ! predicate n v) attrs;
    };

    # removeHomeDirPrefix :: String -> String
    ########################################
    # Given a path, remove the home directory prefix from the path.
    # Ex.
    # removeHomeDirPrefix "/home/user/foo"
    #
    # Returns:
    # "foo"
    removeHomeDirPrefix = path:
      if lib.hasPrefix "/home" path
      then path
        |> lib.splitString "/"
        |> lib.drop 3
        |> lib.concatStringsSep "/"
      else path;

    # shortenRev :: String -> String
    ########################################
    # Shortens a git commit hash to the first 7 characters
    # Ex.
    # shortenRev "acb36a427a35f451b42dd5d0f29f1c4e2fe447b9"
    #
    # Returns:
    # "acb36a4"
    shortenRev = rev: builtins.substring 0 7 rev;

    # }}}
  })).extend (final: prev: [
    # Put lib functions here to grab from unstable
  ]
    |> map (f: { ${f} = fromLibUnstable f; })
    |> prev.mergeAttrsListRecursive
  );
}
