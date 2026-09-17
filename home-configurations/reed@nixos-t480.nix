{ ezModules, ezModules', lib, ... }:

{
  imports = [
    ./reed.nix
    ezModules.core
    ezModules.extra
    ezModules.graphical
    ezModules.media
    ezModules.social
    ezModules'.filesharing.jdownloader
    ezModules'.games.bottles
    ezModules'.games.minecraft
    ezModules'.games.steam
  ];

  # 1080p panel: Fantasque's hairline strokes only read well here when the
  # base font is bold (the shared kitty module defaults to regular weight).
  programs.kitty.settings.font_family =
    lib.mkForce ''family="FantasqueSansM Nerd Font Mono" style="Bold"'';
}
