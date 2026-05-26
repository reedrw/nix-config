{ pkgs, ... }:

{

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TAG+="systemd", ENV{ID_USB_INTERFACES}=="*:ff4201:*", ENV{SYSTEMD_WANTS}+="adb-dismiss-popup.service"
  '';

  systemd.services.adb-dismiss-popup= {
    description = "Dismiss USB popup on AYN Thor";
    after = [ "adb-daemon.service" ];
    path = with pkgs; [ android-tools ];
    serviceConfig = {
      Type = "oneshot";
      User = "adb";
      ExecStart = pkgs.writeShellScript "adb-dismiss-popup" ''
        # -d pins to the USB transport so we don't trip on the stale TCP
        # transport left over from a previous fallback session.
        adb wait-for-usb-device
        # Retry the dumpsys: adb tcpip restarts adbd, which can briefly
        # close adb shell sessions while prepare is running in parallel.
        n=0
        until windows=$(adb -d shell dumpsys window windows 2>&1); do
          n=$((n + 1))
          if [ $n -gt 5 ]; then
            echo "$windows" >&2
            exit 1
          fi
          sleep 1
        done
        if echo "$windows" | grep com.odin.settings | grep -q SYSTEM_ALERT_WINDOW; then
          adb -d shell input -d 0 keyevent KEYCODE_BACK
        fi
      '';
      Restart = "no";
    };
  };
}
