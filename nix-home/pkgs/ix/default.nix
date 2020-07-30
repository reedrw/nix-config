{ pkgs ? import <nixpkgs> {} , stdenv ? pkgs.stdenv }:

let
  sources = import ./nix/sources.nix;
in
stdenv.mkDerivation {
  name = "ix";

  src = with sources.ix;
  builtins.fetchurl {
    url = url;
    sha256 = sha256;
  };

  phases = "installPhase";

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/ix
    chmod +x $out/bin/ix
  '';

  meta = with stdenv.lib; {
    homepage = "http://ix.io";
    description = "command line pastebin";
  };
}

