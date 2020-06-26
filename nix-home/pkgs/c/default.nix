{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
, makeWrapper ? pkgs.makeWrapper
, xclip ? pkgs.xclip
}:

let
  c = pkgs.writeTextFile {
    name = "c";
    executable = true;
    text = ''
      #${pkgs.stdenv.shell}

      if [[ -p /dev/stdin ]] ; then
        xclip -i -selection clipboard
      else
        xclip -o -selection clipboard
      fi
    '';
  };
in
stdenv.mkDerivation rec {
  name = "c";

  src = ./.;

 BuildInputs = [ xclip.out ];
 nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp -v ${c} $out/bin/c
    wrapProgram $out/bin/c \
      --prefix PATH : ${xclip.out}/bin
  '';
}

