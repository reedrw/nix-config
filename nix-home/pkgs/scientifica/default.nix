{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
}:

let

  sources = import ./nix/sources.nix;

in
stdenv.mkDerivation rec {
  name = "scientifica";

  src = builtins.fetchTarball {
    inherit (sources.scientifica) url sha256;
  };

  installPhase = ''
    mkdir -p "$out/share/fonts/"
    install -D -m644 ttf/* "$out/share/fonts/"
  '';

  meta = {
    description = "Tall and condensed bitmap font for geeks.";
    homepage = "https://github.com/NerdyPepper/scientifica";
    license = stdenv.lib.licenses.ofl;
  };
}

