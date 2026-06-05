{ pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
  };

  programs.librepods.enable = true;

  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-bluez-avrcp.conf" ''
      monitor.bluez.properties = {
        bluez5.dummy-avrcp-player = true
      }
    '')
  ];

  custom.persistence.directories = [
    "/var/lib/bluetooth"
  ];
}
