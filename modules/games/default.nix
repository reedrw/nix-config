{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  aagl-gtk-on-nix = import sources.aagl-gtk-on-nix { };

  aagl-gtk-unwrapped = with aagl-gtk-on-nix; an-anime-game-launcher-gtk-unwrapped.overrideAttrs (
    old: with sources.an-anime-game-launcher-gtk; rec {
      version = rev;
      src = sources.an-anime-game-launcher-gtk;
      cargoDeps = old.cargoDeps.overrideAttrs (old: {
        inherit src;
        outputHash = cargoSha256;
      });
    }
  );

in
{
  home.packages = with pkgs; [
    polymc
    (aagl-gtk-on-nix.an-anime-game-launcher-gtk.override {
      an-anime-game-launcher-gtk-unwrapped = aagl-gtk-unwrapped.override {
        customIcon = builtins.fetchurl (lib.importJSON ./icon.json);
      };
    })
  ];
}
