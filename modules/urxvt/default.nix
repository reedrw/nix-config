{ config, lib, pkgs, ... }:

let

  sources = import ./nix/sources.nix;

in
{
  home.file = {
    ".urxvt/ext/font-size".source = "${sources.urxvt-font-size}/font-size";
  };

  xresources.extraConfig = with config.lib.base16.theme; ''

    *foreground:   #${base05}
    *background:   #${base00}

    *color0:       #${base00}
    *color1:       #${base08}
    *color2:       #${base0B}
    *color3:       #${base0A}
    *color4:       #${base0D}
    *color5:       #${base0E}
    *color6:       #${base0C}
    *color7:       #${base05}

    *color8:       #${base03}
    *color9:       #${base08}
    *color10:      #${base0B}
    *color11:      #${base0A}
    *color12:      #${base0D}
    *color13:      #${base0E}
    *color14:      #${base0C}
    *color15:      #${base05}

  '';

  programs.urxvt = {
    enable = true;
    scroll.bar.enable = false;
    fonts = [ "xft:scientifica:size=8" ];
    extraConfig = {
      fontBold = "xft:scientifica:style=Bold:size8";
      fontItalic = "xft:scientifica:style=Italic:size8";
      cursorBlink = 1;
      cursorUnderline = 1;
      internalBorder = 15;
      letterSpace = -6;
      perl-ext-common = "default,matcher,font-size";
      url-launcher = "firefox";
      iso14755 = false;
      "matcher.button" = 1;
      "keysym.Shift-Control-V" = "eval:paste_clipboard";
      "keysym.Shift-Control-C" = "eval:selection_to_clipboard";
      "keysym.C-Up"     = "font-size:increase";
      "keysym.C-Down"   = "font-size:decrease";
    };
  };
  systemd.user = {
    services = {
      urxvtd = {
        Unit = {
          Description = "URxvt Terminal Daemon";
        };
        Service = {
          ExecStart = "${pkgs.rxvt-unicode}/bin/urxvtd -q -o";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}

