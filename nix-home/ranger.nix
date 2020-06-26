{ config, lib, pkgs, ... }:

{

  home.packages = [ pkgs.ranger ];

  home.file = {
    ".config/ranger/rc.conf".source = builtins.toFile "rc.conf" ''
        alias touch shell touch
        map e console touch%space
      '';

    ".config/ranger/rifle.conf".source = builtins.toFile "rifle.conf" ''
        ext nix = ''${VISUAL:-$EDITOR} -- "$@"
        ext sh  = ''${VISUAL:-$EDITOR} -- "$@"
      '';
  };

}

