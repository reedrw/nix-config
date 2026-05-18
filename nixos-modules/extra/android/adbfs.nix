{ pkgs, ... }:

{
  programs.fuse.userAllowOther = true;

  environment.systemPackages = [
    pkgs.adbfs-rootless
  ];

  systemd.tmpfiles.rules = [
    "d /run/media/android 0755 adb adb -"
  ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TAG+="systemd", ENV{ID_USB_INTERFACES}=="*:ff4201:*", ENV{SYSTEMD_WANTS}+="adbfs-mount.service"
    ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ENV{INTERFACE}=="255/66/1", RUN+="${pkgs.systemd}/bin/systemctl stop adbfs-mount.service"
  '';

  systemd.services.adbfs-mount = {
    description = "Mount Android device via adbfs";
    after = [ "adb-daemon.service" ];
    path = with pkgs; [ adbfs-rootless android-tools ];
    serviceConfig = {
      Type = "simple";
      User = "adb";
      ExecStart = "${pkgs.adbfs-rootless}/bin/adbfs /run/media/android -f -o allow_other,auto_unmount";
      Restart = "no";
    };
  };

}
