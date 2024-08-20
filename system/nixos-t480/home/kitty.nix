{ lib, ... }:

{
  programs.kitty.settings = {
    font_size = lib.mkForce 12;
  };
}
