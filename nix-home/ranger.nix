{ config, lib, pkgs, ... }:

{

  home.packages = [ pkgs.ranger ];

  home.file = {
    ".config/ranger/rc.conf".source = pkgs.writeText "rc.conf" ''
        alias touch shell touch
        map e console touch%space
      '';

    ".config/ranger/rifle.conf".source = pkgs.writeText "rifle.conf" ''
        ext nix = ''${VISUAL:-$EDITOR} -- "$@"
      '';
  };

}
