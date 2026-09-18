{ pkgs, lib, util, ... }:

{
  boot.loader.grub.configurationName = lib.mkDefault "Default - ${util.versionSuffix}";
  environment.etc."nixos/tree-version".text = util.versionSuffix;
  services = {
    journald.extraConfig = "SystemMaxUse=500M";
    udisks2.enable = true;
    dbus.implementation = "broker";
    irqbalance.enable = true;
    fstrim.enable = true;
  };

  hardware.i2c.enable = true;

  # set console colors
  stylix.targets.console.enable = true;

  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "30s";
    DefaultTimeoutStopSec = "15s";
    DefaultLimitNOFILE = "2048:1048576";
  };

  # systemd.user.extraConfig = config.systemd.extraConfig;

  # On every (dry-)activation, print a why-trace of what changed in the closure
  # (pkgs/why-diff): per-transition "old → new" versions nested under the
  # package that pulled them in, instead of diff-closures' flat table.
  system.activationScripts.diff = {
    supportsDryActivation = true;
    text = ''
      if [[ -e /run/current-system ]]; then
        ${lib.getExe pkgs.why-diff} /run/current-system "$systemConfig" || true
      fi
    '';
  };

  programs.nano.enable = false;

  # /bin/bash symlink
  system.activationScripts.create-bash-symlink = {
    deps = [ "binsh" "usrbinenv" ];
    text = ''
      ${pkgs.coreutils}/bin/ln -sf /run/current-system/sw/bin/bash /bin/bash
      ${pkgs.coreutils}/bin/ln -sf /run/current-system/sw/bin/bash /usr/bin/bash
    '';
  };

  # Fix xdg-open in FHS sandbox
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common.default = "*";
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  environment.systemPackages = with pkgs; [
    ldp
    xdg-desktop-portal
  ];

  custom.persistence = {
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/tmp"
    ];
    files = [
      "/etc/machine-id"
    ];
  };
}
