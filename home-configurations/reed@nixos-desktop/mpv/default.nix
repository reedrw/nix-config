{ util, ... }:
let
  sources = (util.importFlake ./sources).inputs;
in
{
  # from https://kohana.fi/article/mpv-for-anime#conf_hz
  programs.mpv.config = {
    dither = "error-diffusion";
    dither-depth = "auto";
    error-diffusion = "sierra-lite";

    glsl-shader = "${sources.ArtCNN}/GLSL/ArtCNN_C4F32.glsl";

    scale-antiring = 0.5;
    dscale-antiring = 0.5;
    cscale-antiring = 0.5;

    deband = "yes";
    deband-iterations = 4;
    deband-threshold = 35;
    deband-range = 16;
    deband-grain = 4;
  };
}
