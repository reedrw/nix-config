{ ... }:

{
  environment.etc."crypttab".text = ''
    BigHD /dev/disk/by-uuid/c5d3a438-5719-4020-be28-f258a15c5ab7 /persist/secrets/crypt/BigHD.key luks
  '';

  fileSystems = {
    "/mnt/BigHD" = {
      fsType = "ext4";
      device = "/dev/mapper/BigHD";
      options = [
        "nofail"
      ];
    };
    "/var/lib/deluge/Downloads" = {
      device = "/mnt/BigHD/torrents";
      options = [ "bind" ];
    };
  };
}
