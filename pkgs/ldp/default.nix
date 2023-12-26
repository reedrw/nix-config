{ writeShellScriptBin, runtimeShell, ... }:

(writeShellScriptBin "ldp" (''
  if [ -f "$HOME/.config/nixpkgs/flake.nix" ]; then
    flakePath="$HOME/.config/nixpkgs"
  else
    flakePath="$(pwd)"
  fi
'' + builtins.readFile ../../install.sh)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_ldp} > $out/share/zsh/site-functions/_ldp
  '';
})
