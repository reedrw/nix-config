{ inputs, ... }:

{
  boot.loader.grub.theme = "${inputs.distro-grub-themes}/customize/nixos";
}
