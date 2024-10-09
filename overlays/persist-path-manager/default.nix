{ writeNixShellScript }:

(writeNixShellScript "persist" (builtins.readFile ./persist)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_persist} > $out/share/zsh/site-functions/_persist
  '';
})
