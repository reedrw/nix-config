{ config, pkgs, lib, ... }:
let
  inherit (config.lib) scripts;
in
{
  lib.scripts.rofi-askpass = let
    askpass-rasi = with config.lib.stylix.colors; builtins.toFile "askpass.rasi" ''
      * {
        background-color: #${base01};
        text-color:       #${base07};
      }

      #window {
        /* Change the this according to your screen width */
        width:      380px;

        /* Change this value according to your screen height */
        y-offset: -5%;

        /* This padding is given just for aesthetic purposes */
        padding:    40px;
      }

      #entry {
        /*
         * For some reason, without this option, a dash/hyphen appears
         * at the end of the entry
         */
        expand: true;

        /* Keeping using 200px so that long passwords can be typed */
        width: 200px;
      }
    '';
  in pkgs.writeShellScriptBin "rofi-askpass" ''
    : | rofi -dmenu \
      -sync \
      -password \
      -i \
      -no-fixed-num-lines \
      -p "Password: " \
      -theme ${askpass-rasi} \
      2> /dev/null
  '';

  programs.zsh.initContent = ''
    if [[ ! -z $DISPLAY ]]; then
      export SSH_ASKPASS="${lib.getExe scripts.rofi-askpass}"
      export SUDO_ASKPASS="${lib.getExe scripts.rofi-askpass}"
      alias sudo='sudo -A'
    fi
  '';

  home.packages = [
    scripts.rofi-askpass
  ];
}
