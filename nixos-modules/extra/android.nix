{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    android-file-transfer
    android-tools
    scrcpy
  ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TAG+="systemd", ENV{SYSTEMD_WANTS}="scrcpy-audio.service"
    SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4201:*", GROUP="scrcpy-audio", MODE="0664"
  '';

  users.users.scrcpy-audio = {
    description = "android audio over USB";
    group = "scrcpy-audio";
    extraGroups = [ "pipewire" ];
    isSystemUser = true;
  };

  users.groups.scrcpy-audio = {};

  systemd.services.scrcpy-audio = {
    description = "android audio over USB";
    path = with pkgs; [
      android-tools
      scrcpy
    ];
    serviceConfig = {
      Type = "simple";
      User = "scrcpy-audio";
      StateDirectory = "scrcpy-audio";
      Environment = [
        "HOME=/var/lib/scrcpy-audio"
        "PIPEWIRE_RUNTIME_DIR=/run/pipewire"
        "PULSE_SERVER=unix:/run/pipewire/pulse"
      ];
      ExecStart = pkgs.writeShellScript "scrcpy-audio" ''
        scrcpy --no-window --audio-buffer=30
      '';
    };
  };

  custom.persistence.directories = [
    "/var/lib/scrcpy-audio"
  ];
}
