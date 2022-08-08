{ cfg, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
  aagl-gtk-on-nix = import sources.aagl-gtk-on-nix { };
in
{
  home.packages = with pkgs; [
    polymc
    (with aagl-gtk-on-nix; an-anime-game-launcher-gtk.override {
      an-anime-game-launcher-gtk-unwrapped = an-anime-game-launcher-gtk-unwrapped.overrideAttrs (
        old: with sources.an-anime-game-launcher-gtk; rec {
          version = rev;
          src = sources.an-anime-game-launcher-gtk;
          cargoDeps = old.cargoDeps.overrideAttrs (old: {
            inherit src;
            outputHash = cargoSha256;
          });
        }
      );
    })
  ];
}
