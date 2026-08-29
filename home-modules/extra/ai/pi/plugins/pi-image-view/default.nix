# Vendored fork of pi-image-view — see FORK.md for the deviations from
# upstream and the rebase procedure when updating.
{
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "pi-image-view";
  inherit (builtins.fromJSON (builtins.readFile ./package.json)) version;
  src = ./.;
  dontBuild = true;

  passthru.npmName = "pi-image-view";

  installPhase = ''
    mkdir "$out"
    cp -a ./. "$out/"
  '';
}
