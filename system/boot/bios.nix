{ inputs, outputs, config, pkgs, ... }:

{
  imports = [
    ./theme.nix
  ];

  boot.loader.grub = {
    enable = true;
    version = 2;
  };
}
