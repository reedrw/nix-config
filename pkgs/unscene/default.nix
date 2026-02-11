{ lib, writeShellScriptBin, rar, mountiso }:

(writeShellScriptBin "unscene" (''
  PATH=${lib.makeBinPath [ rar mountiso ]}:$PATH
'' + builtins.readFile ./unscene.sh)).overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    mkdir -p $out/share/zsh/site-functions
    cat ${./_unscene} > $out/share/zsh/site-functions/_unscene
  '';
})
