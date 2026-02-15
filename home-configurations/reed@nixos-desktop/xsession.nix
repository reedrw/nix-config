{ pkgs, ... }:

{
  xsession.windowManager.i3.config.startup = let
    alwaysRun = [
      "${pkgs.writeShellScript "line-in-to-easyeffects" ''
        sleep 10
        pw-link "alsa_input.pci-0000_18_00.6.analog-stereo:capture_FL" "easyeffects_sink:playback_FL"
        pw-link "alsa_input.pci-0000_18_00.6.analog-stereo:capture_FR" "easyeffects_sink:playback_FR"
      ''}"
    ];
    run = [
      "xrandr --output DisplayPort-0 --mode 1920x1080 --rate 144"
      "xrandr --output DisplayPort-1 --mode 1920x1080 --rate 144"
      "xrandr --output DisplayPort-2 --mode 1920x1080 --rate 144"
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
