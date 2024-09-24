{ writeShellScriptBin
, flakePath
}:

(writeShellScriptBin "ldp" (''
  if [ -f "${flakePath}/flake.nix" ]; then
    flakePath="${flakePath}"
  else
    flakePath="$(pwd)"
  fi
'' + builtins.readFile ../../install.sh)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_ldp} > $out/share/zsh/site-functions/_ldp
  '';
})
