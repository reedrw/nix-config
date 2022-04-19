{ config, pkgs, ... }:

{
  boot.loader.grub = {
    enable = true;
    version = 2;
  };
}
