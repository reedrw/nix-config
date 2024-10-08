{
  imports = [
    ./bios.nix
    ./efi.nix
    ./remote-unlock.nix
    ./keyfile-unlock.nix
    ./theme.nix
    ./wipe
  ];

  boot.initrd.systemd.enable = true;
}
