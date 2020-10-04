{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
}:

stdenv.mkDerivation rec {
  pname = "scientifica";
  version = "2.1";

  src = builtins.fetchTarball {
    url = "https://github.com/NerdyPepper/scientifica/releases/download/v${version}/scientifica-v${version}.tar";
    sha256 = "1mji70h5qdplx0rlhijrdpbmvd0c6fvnr70sla032gfs5g6f78cn";
  };

  installPhase = ''
    mkdir -p "$out/share/fonts/"
    install -D -m644 ttf/* "$out/share/fonts/"
  '';

  meta = {
    description = "tall, condensed, bitmap font for geeks.";
    homepage = "https://github.com/NerdyPepper/scientifica";
    license = stdenv.lib.licenses.ofl;
  };
}

