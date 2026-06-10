{ osConfig, lib, ... }:

let
  session = osConfig.custom.session or "i3";
in
{
  imports = [
    ./gnome # only enabled if gnome is enabled in system config
  ]
  ++ lib.optional (session == "i3") ./i3
  ++ lib.optional (session == "sway") ./sway;

  custom.persistence.directories = [
    ".cache/mesa_shader_cache"
  ];
}
