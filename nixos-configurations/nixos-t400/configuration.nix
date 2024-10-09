{ inputs, ... }:

{

  imports = [
    ./hardware-configuration.nix
    "${inputs.nixos-hardware}/lenovo/thinkpad/t410"
    # inputs.attic.nixosModules.atticd
  ];

  networking.hostName = "nixos-t400";
  nixpkgs.hostPlatform = "x86_64-linux";

  custom.boot.bios.enable = true;
  boot.loader.grub.device = "/dev/sda";

  programs.dconf.enable = true;

  hardware.trackpoint = {
    enable = true;
    emulateWheel = true;
  };

  services.mullvad-vpn.enable = false;
  services.logind.lidSwitch = "ignore";

  networking.firewall.allowedTCPPorts = [
    8080
  ];

  # services.atticd = {
  #   enable = true;
  #   credentialsFile = "/etc/atticd.env";
  #
  #   settings = {
  #     listen = "[::]:8080";
  #
  #     # Data chunking
  #     #
  #     # Warning: If you change any of the values here, it will be
  #     # difficult to reuse existing chunks for newly-uploaded NARs
  #     # since the cutpoints will be different. As a result, the
  #     # deduplication ratio will suffer for a while after the change.
  #     chunking = {
  #       # The minimum NAR size to trigger chunking
  #       #
  #       # If 0, chunking is disabled entirely for newly-uploaded NARs.
  #       # If 1, all NARs are chunked.
  #       nar-size-threshold = 64 * 1024; # 64 KiB
  #
  #       # The preferred minimum size of a chunk, in bytes
  #       min-size = 16 * 1024; # 16 KiB
  #
  #       # The preferred average size of a chunk, in bytes
  #       avg-size = 64 * 1024; # 64 KiB
  #
  #       # The preferred maximum size of a chunk, in bytes
  #       max-size = 256 * 1024; # 256 KiB
  #     };
  #   };
  # };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.03"; # Did you read the comment?

}

