{ config, lib, pkgs, ... }:

{

  home.file = {
    ".config/ranger/rc.conf".source = pkgs.writeTextFile {
      name = "rc.conf";
      text = ''
        alias touch shell touch
        map e console touch%space
      '';
    };

    ".config/ranger/rifle.conf".source = pkgs.writeTextFile {
      name = "rc.conf";
      text = ''
        ext nix = ''${VISUAL:-$EDITOR} -- "$@"
      '';
    };
  };

}
