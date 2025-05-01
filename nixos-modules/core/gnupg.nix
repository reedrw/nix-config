{ pkgs, ... }:

{
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  services.gnome.gnome-keyring.enable = true;

  security.pam.services = {
    gdm.enableGnomeKeyring = true;
    login = {
      enable = true;
      enableGnomeKeyring = true;
    };
  };

}
