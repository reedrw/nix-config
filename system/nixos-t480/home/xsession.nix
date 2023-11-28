{ pkgs, ... }:

{
  xsession.windowManager.i3.config.startup = let
    alwaysRun = [];
    run = [
      "${pkgs.writeShellScript "natural-scroll" ''
        #!/usr/bin/env bash
        id="$(xinput list | grep -o 'Synaptics.*id=[0-9]*' | cut -d= -f2)"
        xinput set-prop "$id" "libinput Natural Scrolling Enabled" 1
      ''}"
    ];
  in map ( command: {
    inherit command;
    always = true;
    notification = false;
  }) alwaysRun ++ map ( command: {
    inherit command;
    notification = false;
  }) run;
}
