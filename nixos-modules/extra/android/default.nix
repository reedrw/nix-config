{ pkgs, ... }:

{
  imports = builtins.readDir ./.
    |> (x: builtins.removeAttrs x ["default.nix"])
    |> builtins.attrNames
    |> map (x: ./${x});

  environment.systemPackages = [
    pkgs.android-tools
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4201:*", GROUP="adb", MODE="0664"
  '';

  users.users.adb = {
    home = "/var/lib/adb";
    description = "Android Debug Bridge user";
    group = "adb";
    isSystemUser = true;
    createHome = true;
  };
  users.groups.adb = {};

  systemd.services.adb-daemon = {
    description = "ADB daemon";
    path = with pkgs; [ android-tools ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      User = "adb";
      ExecStart = "${pkgs.android-tools}/bin/adb start-server";
      ExecStop = "${pkgs.android-tools}/bin/adb kill-server";
      RemainAfterExit = true;
    };
  };

  custom.persistence.directories = [
    "/var/lib/adb"
  ];
}
