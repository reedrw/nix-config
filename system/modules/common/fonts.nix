{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      cantarell-fonts
      carlito
      corefonts
      dejavu_fonts
      ipafont
      kochi-substitute
      noto-fonts-emoji
      open-sans
      source-code-pro
      ttf_bitstream_vera
      (nerdfonts.override {
        fonts = [
          "FantasqueSansMono"
          "CascadiaCode"
        ];
      })
    ];
    fontconfig = {
      enable = true;
      cache32Bit = true;
      subpixel.rgba = "rgb";
      defaultFonts = {
        monospace = [
          "CaskaydiaCove Nerd Font Mono"
          "Bitstream Vera Sans Mono"
          "DejaVu Sans Mono"
          "IPAGothic"
        ];
        sansSerif = [
          "Bitstream Vera Sans"
          "DejaVu Sans Serif"
          "IPAPGothic"
        ];
        serif = [
          "Bitstream Vera Serif"
          "DejaVu Serif"
          "IPAPMincho"
        ];
      };
    };
  };
}
