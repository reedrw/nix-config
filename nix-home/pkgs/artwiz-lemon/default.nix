{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
}:

let

  sources = import ./nix/sources.nix;

in
stdenv.mkDerivation rec {
  name = "artwiz-lemon";

  src = fetchFromGitHub {
    owner = sources.artwiz-lemon.owner;
    repo = sources.artwiz-lemon;
    rev = sources.artwiz-lemon.rev;
    sha256 = sources.artwiz-lemon.sha256;
  };

  installPhase = ''
    install -D -m644 lemon.bdf "$out/share/fonts/lemon.bdf"
  '';

}
