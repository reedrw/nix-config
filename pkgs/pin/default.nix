{ writeNixShellScript, flakePath, stdenv }:

(writeNixShellScript "pin" (builtins.readFile ./pin)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_pin} > $out/share/zsh/site-functions/_pin

    contents="$(cat $out/bin/pin)"
    cat << EOF > $out/bin/pin
    #!${stdenv.shell}
    if [ -d "${flakePath}/" ]; then
      flakePath="${flakePath}"
    fi
    EOF
    echo "''${contents}" >> $out/bin/pin
  '';
})
