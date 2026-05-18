{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.scrcpy
  ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TAG+="systemd", ENV{ID_USB_INTERFACES}=="*:ff4201:*", ENV{SYSTEMD_WANTS}+="scrcpy-audio.service"
  '';

  users.users.adb.extraGroups = [ "pipewire" ];

  systemd.services.scrcpy-audio = {
    description = "android audio over USB";
    after = [ "adb-daemon.service" ];
    path = with pkgs; [
      android-tools
      scrcpy
    ];
    serviceConfig = {
      Type = "simple";
      User = "adb";
      StateDirectory = "scrcpy-audio";
      Environment = [
        "PIPEWIRE_RUNTIME_DIR=/run/pipewire"
        "PULSE_SERVER=unix:/run/pipewire/pulse"
      ];
      ExecStart = pkgs.writeShellScript "scrcpy-audio" ''
        scrcpy --no-window
      '';
    };
  };
}
