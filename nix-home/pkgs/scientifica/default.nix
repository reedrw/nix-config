{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
, fontforge ? pkgs.fontforge
, jre ? pkgs.jre
}:

let

  sources = import ./nix/sources.nix;

  BNP = with sources.bitsnpicas;
  fetchFromGitHub {
    owner = owner;
    repo = repo;
    rev = rev;
    sha256 = sha256;
  };
in
stdenv.mkDerivation rec {
  name = "scientifica";

  src = with sources.scientifica;
  fetchFromGitHub {
    owner = owner;
    repo = name;
    rev = rev;
    sha256 = sha256;
  };

  nativeBuildInputs = [ fontforge jre ];

  buildPhase = ''
    patchShebangs ./build.sh
    export BNP="${BNP}/downloads/BitsNPicas.jar"
    ./build.sh
  '';

  installPhase = ''
    mkdir -p "$out/share/fonts/"
    install -D -m644 build/scientifica/otb/* "$out/share/fonts/"
    install -D -m644 build/scientifica/ttf/* "$out/share/fonts/"
  '';

  meta = {
    description=sources.scientifica.description;
    homepage="https://github.com/NerdyPepper/scientifica";
    license = stdenv.lib.licenses.ofl;
  };
}

