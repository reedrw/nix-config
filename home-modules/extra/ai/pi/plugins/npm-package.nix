# Unpacks a pinned npm tarball for direct loading by pi (jiti reads the TS/JS
# in place, peer deps on @earendil-works/* are provided by pi itself) and
# assembles a flat node_modules for declared runtime dependencies from the
# other pinned packages in ./pins.json.
{
  name,
  pin,
  npmPkgs, # full pinned set, for dependency resolution (lazy, acyclic)
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
    ${lib.concatMapStringsSep "\n" (dep: ''
      mkdir -p "$out/node_modules/${dirOf dep}"
      ln -s "${npmPkgs.${dep}}" "$out/node_modules/${dep}"
    '') (pin.dependencies or [ ])}
  '';
}
