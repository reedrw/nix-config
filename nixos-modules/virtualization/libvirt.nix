{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  custom.persistence = {
    directories = [
      "/var/lib/libvirt"
    ];
    # https://github.com/NixOS/nixpkgs/issues/501336#issuecomment-4890126510
    # if bad credentials:
    # rm /var/lib/libvirt/secrets/secrets-encryption-key
    # systemctl start virt-secret-init-encryption.service
    files = [
      "/etc/machine-id"
    ];
  };
}
