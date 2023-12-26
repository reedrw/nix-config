{ writeShellScriptBin, runtimeShell, ... }:

(writeShellScriptBin "ldp" (''
  flakePath=/home/reed/.config/nixpkgs
'' + builtins.readFile ../../install.sh)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_ldp} > $out/share/zsh/site-functions/_ldp
  '';
})
