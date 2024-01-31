{ stdenv, python3, ... }:
let
  sources = import ../nix/sources.nix { };
in
stdenv.mkDerivation {
  name = "mpv_thumbnail_script";
  src = sources.mpv_thumbnail_script;

  nativeBuildInputs = [ python3 ];

  patchPhase = ''
    patchShebangs ./concat_files.py
  '';

  installPhase = ''
    mkdir -p "$out"
    cp *.lua "$out"
  '';
}
