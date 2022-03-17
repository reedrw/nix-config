{ config, lib, pkgs, ... }:

{
  programs.zsh.initExtra =
    let
      askpass-rasi = with config.lib.base16.theme; builtins.toFile "askpass.rasi" ''
        * {
            background-color: #${base00-hex};
            text-color:       #${base07-hex};
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
      rofi-askpass = pkgs.writeShellScript "rofi-askpass" ''
        rofi -dmenu\
          -password\
          -i\
          -no-fixed-num-lines\
          -p "Password: "\
          -theme ${askpass-rasi} \
          2> /dev/null
      '';
  in
  ''
    if [[ ! -z $DISPLAY ]]; then
      export SSH_ASKPASS="${rofi-askpass}"
      export SUDO_ASKPASS="${rofi-askpass}"
      alias sudo='sudo -A'
    fi
  '';
}
