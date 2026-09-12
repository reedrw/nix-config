# pi-pet assets — kitty-graphics frame sequences generated from pi-dsh-pet's
# transparent WebM animations.
#
# Upstream (https://github.com/SOMWHY/pi-dsh-pet, MIT) renders its desktop pet
# in an Electron window playing 91 transparent VP9 WebM clips. The WebM frames
# have a solid black background (no alpha), so each clip is keyed to
# transparency and cropped to the character's bounding box (see build.py —
# the pi overlay band erases the text under it, so it must hug the pet),
# quantized to palette PNG frames the pi extension uploads over the kitty
# graphics protocol (f=100), plus a manifest with frame counts for the
# terminal-driven animation loop (a=f frames + a=a s=3).
#
# Output layout:
#   <name>/f0001.png .. fNNNN.png   palette PNG frames (RGBA palette, 256x144)
#   manifest.json                   { "<name>": { frames, fps, width, height } }
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  ffmpeg,
  python3,
}:
let
  rev = "7d3aa2defc4fe548ad389f5c0f1a8dd793ae309e";
  fps = 10;
in
stdenvNoCC.mkDerivation {
  pname = "pi-pet-assets";
  version = "0-unstable-${builtins.substring 0 7 rev}";

  src = fetchFromGitHub {
    owner = "SOMWHY";
    repo = "pi-dsh-pet";
    inherit rev;
    hash = "sha256-sw9iZM2y4SQQK1QrWTm2I4s7h6Sp1oZBZxTiChP+k38=";
  };

  nativeBuildInputs = [ ffmpeg python3 ];

  buildPhase = ''
    runHook preBuild
    mkdir -p "$out"
    python3 ${./build.py} "$src" "$out" ${toString fps}
    runHook postBuild
  '';

  dontInstall = true;

  meta = {
    description = "Kitty-graphics frame sequences for the pi desktop pet (from pi-dsh-pet)";
    license = lib.licenses.mit;
  };
}
