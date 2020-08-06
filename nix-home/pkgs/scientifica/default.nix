{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
}:

let

  sources = import ./nix/sources.nix;

in
stdenv.mkDerivation rec {
  name = "scientifica";

  src = sources.scientifica;

  installPhase = ''
    mkdir -p "$out/share/fonts/"
    install -D -m644 ttf/* "$out/share/fonts/"
  '';

  meta = {
    inherit (sources.scientifica) description homepage;
    license = stdenv.lib.licenses.ofl;
  };
}

