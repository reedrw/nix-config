{ config, pkgs, ... }:

{
  programs.gnupg.agent = {
    enable = true;
    pinentryFlavor = "tty";
  };
}
