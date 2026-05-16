{ pkgs, ... }:

{

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TAG+="systemd", ENV{SYSTEMD_WANTS}+="adb-dismiss-popup.service"
  '';

  systemd.services.adb-dismiss-popup= {
    description = "Dismiss USB popup on AYN Thor";
    after = [ "adb-daemon.service" ];
    path = with pkgs; [ android-tools ];
    serviceConfig = {
      Type = "oneshot";
      User = "adb";
      ExecStart = pkgs.writeShellScript "adb-dismiss-popup" ''
        adb wait-for-device && \
        if adb shell dumpsys window windows \
          | grep com.odin.settings \
          | grep -q SYSTEM_ALERT_WINDOW
        then
          adb shell input -d 0 keyevent KEYCODE_BACK
        fi
      '';
      Restart = "no";
    };
  };
}
