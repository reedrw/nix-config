{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
}:

let

  sources = import ./nix/sources.nix;

in
stdenv.mkDerivation rec {
  name = "artwiz-lemon";

  src = with sources.artwiz-lemon;
  fetchFromGitHub {
    owner = owner;
    repo = repo;
    rev = rev;
    sha256 = sha256;
  };

  installPhase = ''
    install -D -m644 lemon.bdf "$out/share/fonts/lemon.bdf"
  '';

}

