{ config, lib, ... }:
let
  cfg = config.custom.display;
  referenceResolution = 1080;
in
{
  options.custom.display = {
    verticalResolution = lib.mkOption {
      type = lib.types.int;
      default = referenceResolution;
      description = ''
        Vertical resolution of the primary display in pixels. Acts as a single
        knob that scales every hand-tuned pixel- and font-size literal
        throughout the config relative to a ${toString referenceResolution}p
        baseline (1440 → ×1.33, 2160 → ×2).

        This intentionally does *not* drive Wayland output scale (e.g.
        `sway.config.output.<o>.scale`). The compositor stays at 1× and we
        instead pick larger native pixel sizes, so text and lines stay crisp
        rather than being bilinearly upscaled.
      '';
    };

    scale = lib.mkOption {
      type = lib.types.float;
      readOnly = true;
      description = "Scale factor relative to the ${toString referenceResolution}p baseline.";
    };

    dp = lib.mkOption {
      type = lib.types.functionTo lib.types.int;
      readOnly = true;
      description = ''
        Density-independent unit: scales a baseline value (calibrated at
        ${toString referenceResolution}p, where 1 dp = 1 px) by the current
        scale factor and rounds to the nearest integer. Use for any value
        that should grow with the display — pixel sizes, font points, gaps,
        paddings — inserted directly as a Nix value or stringified into
        CSS / config files.
      '';
    };
  };

  config.custom.display = {
    scale = cfg.verticalResolution * 1.0 / referenceResolution;
    dp = n: builtins.floor (n * cfg.scale + 0.5);
  };
}
