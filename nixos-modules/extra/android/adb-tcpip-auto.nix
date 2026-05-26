{ pkgs, ... }:

let
  # The `adb tcpip` command restarts adbd on the device, causing the USB ADB
  # interface to remove+readd. That re-fires both ADD and REMOVE udev rules,
  # which we ignore for a few seconds after a successful prepare.
  recentlyRanTcpip = ''[ -s /run/adb-tcpip/last-tcpip ] && [ $(($(date +%s) - $(cat /run/adb-tcpip/last-tcpip))) -lt 5 ]'';
in
{
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TAG+="systemd", ENV{ID_USB_INTERFACES}=="*:ff4201:*", ENV{SYSTEMD_WANTS}+="adb-tcpip-prepare.service"
    ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ENV{INTERFACE}=="255/66/1", TAG+="systemd", RUN+="${pkgs.systemd}/bin/systemctl start adb-tcpip-fallback.service"
  '';

  systemd.services.adb-tcpip-prepare = {
    description = "Enable adb TCP/IP mode on newly plugged-in device";
    after = [ "adb-daemon.service" ];
    requires = [ "adb-daemon.service" ];
    before = [
      "scrcpy-audio.service"
      "adbfs-mount.service"
    ];
    path = with pkgs; [ android-tools gawk ];
    serviceConfig = {
      Type = "oneshot";
      User = "adb";
      RuntimeDirectory = "adb-tcpip";
      RuntimeDirectoryPreserve = "yes";
      # Stop any services still running over the previous TCP session and
      # drop the stale TCP transport before USB-bound services start.
      ExecStartPre = "+${pkgs.writeShellScript "adb-tcpip-prepare-pre" ''
        if ${recentlyRanTcpip}; then exit 0; fi
        systemctl stop scrcpy-audio.service adbfs-mount.service
      ''}";
      ExecStart = pkgs.writeShellScript "adb-tcpip-prepare" ''
        set -eu
        if ${recentlyRanTcpip}; then
          echo "tcpip ran recently; skipping (likely adbd-restart re-trigger)" >&2
          exit 0
        fi
        adb disconnect || true
        adb wait-for-usb-device
        ip=$(adb -d shell "ip route get 1.1.1.1 2>/dev/null" \
          | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit }}' \
          | tr -d '\r\n')
        if [ -z "$ip" ]; then
          echo "could not determine device IP (no Wi-Fi/cellular?)" >&2
          exit 1
        fi
        echo "$ip" > /run/adb-tcpip/ip
        # Mark before tcpip so the transient USB drop it causes is debounced
        # by anything that reads /run/adb-tcpip/last-tcpip.
        date +%s > /run/adb-tcpip/last-tcpip
        adb tcpip 5555
        n=0
        until adb -d wait-for-device 2>/dev/null; do
          n=$((n + 1))
          if [ $n -gt 10 ]; then
            echo "USB transport did not return after tcpip" >&2
            exit 1
          fi
          sleep 1
        done
      '';
    };
  };

  systemd.services.adb-tcpip-fallback = {
    description = "Switch scrcpy/adbfs to adb TCP after USB unplug";
    after = [ "adb-daemon.service" ];
    requires = [ "adb-daemon.service" ];
    path = with pkgs; [ android-tools ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "adb-tcpip-fallback" ''
        set -u
        # Ignore transient USB drops caused by prepare's adb tcpip restart.
        if ${recentlyRanTcpip}; then
          echo "tcpip ran recently; skipping fallback for transient USB drop" >&2
          exit 0
        fi

        if [ ! -f /run/adb-tcpip/ip ]; then
          echo "no IP captured at last plug-in; cannot fall back to TCP" >&2
          exit 0
        fi
        ip=$(cat /run/adb-tcpip/ip)

        systemctl stop scrcpy-audio.service adbfs-mount.service

        adb connect "$ip:5555"

        n=0
        until adb -e get-state 2>/dev/null | grep -q "^device$"; do
          n=$((n + 1))
          if [ $n -gt 10 ]; then
            echo "TCP transport did not come up at $ip:5555" >&2
            exit 1
          fi
          sleep 1
        done

        systemctl start --no-block scrcpy-audio.service adbfs-mount.service
      '';
    };
  };
}
