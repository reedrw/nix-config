{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "c" ''

  xclip(){
    ${pkgs.xclip}/bin/xclip "$@"
  }

  [[ -p /dev/stdin ]] && \
    xclip -i -selection clipboard || \
    xclip -o -selection clipboard
''

