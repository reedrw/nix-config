{ writeNixShellScript }:

(writeNixShellScript "pin" (builtins.readFile ./pin)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_pin} > $out/share/zsh/site-functions/_pin
  '';
})
