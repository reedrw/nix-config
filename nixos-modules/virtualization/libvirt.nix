{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  custom.persistence.directories = [
    "/var/lib/libvirt"
  ];

  # https://github.com/NixOS/nixpkgs/issues/501336 — libvirtd deletes
  # /var/lib/systemd/credential.secret (systemd's local credential key),
  # causing subsequent starts to fail with status=243/CREDENTIALS.
  systemd.services.libvirtd.serviceConfig.ReadOnlyPaths = [
    "/var/lib/systemd/credential.secret"
  ];
}
