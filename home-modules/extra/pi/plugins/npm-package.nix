# Unpacks a pinned npm tarball for direct loading by pi (jiti reads the TS/JS
# in place, peer deps on @earendil-works/* are provided by pi itself).
#
# `patches` are plain unified diffs applied at -p1 in the unpacked package root
# (see packagePatches in default.nix): local fixes to a pinned dependency
# without forking it. A patch that no longer applies fails the build loudly on
# the next pins bump — which is the wanted behavior, not a nuisance.
#
# No node_modules is assembled here: npm dependency graphs may contain cycles
# (e.g. es-abstract <-> arraybuffer.prototype.slice), which store paths cannot
# express. plugins/default.nix instead builds one flat shared node_modules
# (npm's deduped layout) and root plugins symlink it in.
{
  name,
  pin,
  patches ? [ ],
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  tarballName = lib.last (lib.splitString "/" name);
in
stdenvNoCC.mkDerivation {
  pname = "pi-npm-${lib.replaceStrings [ "@" "/" ] [ "" "-" ] name}";
  inherit (pin) version;
  inherit patches;
  src = fetchurl {
    url = "https://registry.npmjs.org/${name}/-/${tarballName}-${pin.version}.tgz";
    inherit (pin) hash;
  };
  sourceRoot = "package";
  dontBuild = true;

  passthru.npmName = name;

  installPhase = ''
    mkdir "$out"
    cp -a ./. "$out/"
  '';
}
