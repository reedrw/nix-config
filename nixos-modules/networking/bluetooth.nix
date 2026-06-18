{ pkgs, ... }:

{
  hardware.bluetooth.enable = true;

  programs.librepods.enable = true;

  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-bluez-avrcp.conf" ''
      monitor.bluez.properties = {
        bluez5.dummy-avrcp-player = true
        bluez5.codecs = [ aac sbc_xq sbc ]
        bluez5.auto-connect = [ a2dp_sink ]
      }
    '')
  ];

  custom.persistence.directories = [
    "/var/lib/bluetooth"
  ];
}
