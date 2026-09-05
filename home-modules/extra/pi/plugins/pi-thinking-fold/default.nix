# Vendored fork of @99percentpeople/pi-thinking-fold — see FORK.md for the
# deviations from upstream and the rebase procedure when updating.
{
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "pi-thinking-fold";
  inherit (builtins.fromJSON (builtins.readFile ./package.json)) version;
  src = ./.;
  dontBuild = true;

  passthru.npmName = "pi-thinking-fold";

  installPhase = ''
    mkdir "$out"
    cp -a ./. "$out/"
  '';
}
