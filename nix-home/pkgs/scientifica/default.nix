{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
, fontforge ? pkgs.fontforge
, jre ? pkgs.jre
}:

let

  sources = import ./nix/sources.nix;

  BNP = fetchFromGitHub {
    owner = sources.bitsnpicas.owner;
    repo = sources.bitsnpicas.repo;
    rev = sources.bitsnpicas.rev;
    sha256 = sources.bitsnpicas.sha256;
  };
in
stdenv.mkDerivation rec {
  pname = "scientifica";
  version = "2.1";

  src = fetchFromGitHub {
    owner = sources.scientifica.owner;
    repo = pname;
    rev = sources.scientifica.rev;
    sha256 = sources.scientifica.sha256;
  };

  nativeBuildInputs = [ fontforge jre ];

  buildPhase = ''
    patchShebangs ./build.sh
    export BNP="${BNP}/downloads/BitsNPicas.jar"
    ./build.sh
  '';


  installPhase = ''
    install -D -m644 build/scientifica/otb/scientifica.otb          "$out/share/fonts/scientifica.otb"
    install -D -m644 build/scientifica/otb/scientificaBold.otb      "$out/share/fonts/scientificaBold.otb"
    install -D -m644 build/scientifica/otb/scientificaItalic.otb    "$out/share/fonts/scientificaItalic.otb"
    install -D -m644 build/scientifica/ttf/scientifica.ttf          "$out/share/fonts/scientifica.ttf"
    install -D -m644 build/scientifica/ttf/scientificaBold.ttf      "$out/share/fonts/scientificaBold.ttf"
    install -D -m644 build/scientifica/ttf/scientificaItalic.ttf    "$out/share/fonts/scientificaItalic.ttf"
  '';

  meta = {
    description=sources.scientifica.description;
    homepage="https://github.com/NerdyPepper/scientifica";
    license = stdenv.lib.licenses.ofl;
  };
}
