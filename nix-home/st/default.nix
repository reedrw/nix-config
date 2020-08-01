{ config, lib, pkgs, ... }:

let

  st = pkgs.st.override {
    patches = [
      "${config.lib.base16.base16template "st"}"
      (builtins.fetchurl {
        url="https://st.suckless.org/patches/scrollback/st-scrollback-20200419-72e3f6c.diff";
        sha256 = "042k00iy8fvr3xvq93fmnhmjqpl1kns24x50xsa82npgllbzwh8y";
      })
      (builtins.fetchurl {
        url="https://st.suckless.org/patches/scrollback/st-scrollback-mouse-20191024-a2c479c.diff";
        sha256 = "0z961sv4pxa1sxrbhalqzz2ldl7qb26qk9l11zx1hp8rh3cmi51i";
      })
      (builtins.toFile "appearance.diff" ''
        diff --git a/config.def.h b/config.def.h
        index 6f05dce..5cb1be5 100644
        --- a/config.def.h
        +++ b/config.def.h
        @@ -5,8 +5,8 @@
          *
          * font: see http://freedesktop.org/software/fontconfig/fontconfig-user.html
          */
        -static char *font = "Liberation Mono:pixelsize=12:antialias=true:autohint=true";
        -static int borderpx = 2;
        +static char *font = "scientifica:size=8";
        +static int borderpx = 15;

         /*
          * What program is execed by st depends of these precedence rules:
      '')
    ];
  };

in
{
  home.packages = [ st ];
}

