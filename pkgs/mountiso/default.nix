{ writeShellScriptBin }:

(writeShellScriptBin "mountiso" (builtins.readFile ./mountiso.sh)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_mountiso} > $out/share/zsh/site-functions/_mountiso
  '';
})
