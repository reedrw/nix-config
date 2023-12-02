{ ... }:
{
  imports = [
    ./bios.nix
    ./efi.nix
    ./remote-unlock.nix
    ./theme.nix
    ./wipe
  ];
}
