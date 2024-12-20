{ lib, ... }:

{

  boot = {
    plymouth.enable = lib.mkForce false;
    initrd.systemd.enable = lib.mkForce false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.hostName = "nixos-iso";

  users.users.reed.password = "password";

  time.timeZone = "America/New_York";

  system.stateVersion = lib.trivial.release;
}
