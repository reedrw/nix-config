{
  imports = [
    ./gnome # only enabled if gnome is enabled in system config
    ./i3
  ];

  custom.persistence.directories = [
    ".cache/mesa_shader_cache"
  ];
}
