{ inputs, outputs, config, pkgs, ... }:

{
  boot.loader.grub.theme = "${inputs.distro-grub-themes}/customize/nixos";
}
