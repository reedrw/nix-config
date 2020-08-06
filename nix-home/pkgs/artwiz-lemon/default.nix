{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
}:

let

  sources = import ./nix/sources.nix;

in
stdenv.mkDerivation rec {
  name = "artwiz-lemon";

  src = (sources.artwiz-lemon);

  installPhase = ''
    install -D -m644 lemon.bdf "$out/share/fonts/lemon.bdf"
  '';

}

