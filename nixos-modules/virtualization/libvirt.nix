{
  # https://github.com/NixOS/nixpkgs/issues/501336
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  custom.persistence.directories = [
    "/var/lib/libvirt"
  ];
}
