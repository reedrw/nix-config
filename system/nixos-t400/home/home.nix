{ lib, ... }:

{
  programs.firefox.enable = lib.mkForce false;
  programs.kitty.enable = lib.mkForce false;
  programs.mpv.enable = lib.mkForce false;
  programs.obs-studio.enable = lib.mkForce false;
  programs.rofi.enable = lib.mkForce false;
  programs.zathura.enable = lib.mkForce false;
  services.dunst.enable = lib.mkForce false;
  services.easyeffects.enable = lib.mkForce false;
  services.mpd.enable = lib.mkForce false;
  services.picom.enable = lib.mkForce false;
  services.polybar.enable = lib.mkForce false;
  xsession.enable = lib.mkForce false;
}
