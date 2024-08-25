{
  xsession.windowManager.i3.config.startup = let
    alwaysRun = [];
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
