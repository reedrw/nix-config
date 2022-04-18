{ config, pkgs, ... }:
let
  dummy-hw = builtins.toFile "dummy.nix" ''
    {
      fileSystems."/".device = "/dev/sda1";
      fileSystems."/".fsType = "ext4";
    }
  '';

  hw = if builtins.pathExists /etc/nixos/hardware-configuration.nix then
    import /etc/nixos/hardware-configuration.nix else import dummy-hw;
in
{
  imports = [
    hw
  ];
}
