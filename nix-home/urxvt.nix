{ config, lib, pkgs, ... }:

let

  sources = import ./nix/sources.nix;

  urxvt-font-size = pkgs.fetchFromGitHub {
    owner = sources.urxvt-font-size.owner;
    repo = sources.urxvt-font-size.repo;
    rev = sources.urxvt-font-size.rev;
    sha256 = sources.urxvt-font-size.sha256;
  };
in
{
  home.file = {
    ".urxvt/ext/font-size".source = "${urxvt-font-size}/font-size";
  };

  xresources.extraConfig = builtins.readFile "${config.lib.base16.base16template "xresources"}";

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
}

