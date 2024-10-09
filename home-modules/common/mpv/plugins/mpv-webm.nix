{ stdenv, luaPackages,  ... }:
let
  sources = import ../nix/sources.nix { };
in
stdenv.mkDerivation {
  name = "mpv-webm";
  src = sources.mpv-webm;

  nativeBuildInputs = with luaPackages; [
    argparse
    moonscript
  ];

  installPhase = ''
    mkdir -p $out/build
    cp build/* $out/build
  '';

}
