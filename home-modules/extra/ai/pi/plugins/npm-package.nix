# Unpacks a pinned npm tarball for direct loading by pi (jiti reads the TS/JS
# in place, peer deps on @earendil-works/* are provided by pi itself).
#
# No node_modules is assembled here: npm dependency graphs may contain cycles
# (e.g. es-abstract <-> arraybuffer.prototype.slice), which store paths cannot
# express. plugins/default.nix instead builds one flat shared node_modules
# (npm's deduped layout) and root plugins symlink it in.
{
  name,
  pin,
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
