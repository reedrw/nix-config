{ config, pkgs, lib, versionSuffix, ... }:

{
  boot.loader.grub.configurationName = lib.mkDefault "Default - ${versionSuffix}";
  environment.etc."nixos/tree-version".text = versionSuffix;
  services.journald.extraConfig = "SystemMaxUse=500M";
  services.udisks2.enable = true;

  security.sudo.extraConfig = ''
    # Prevent arbitrary code execution as your user when sudoing to another
    # user due to TTY hijacking via TIOCSTI ioctl.
    Defaults use_pty
  '';

  services.dbus.implementation = "broker";
  services.irqbalance.enable = true;
  services.fstrim.enable = true;

  # set console colors
  stylix.targets.console.enable = true;

  systemd.extraConfig = ''
    DefaultTimeoutStartSec=30s
    DefaultTimeoutStopSec=15s
    DefaultLimitNOFILE=2048:1048576
  '';
  systemd.user.extraConfig = config.systemd.extraConfig;

  # /bin/bash symlink
  systemd.services.create-bash-symlink = {
    description = "Create /bin/bash symlink";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "create-bash-symlink" ''
        ${pkgs.coreutils}/bin/ln -sfv /run/current-system/sw/bin/bash /bin/bash
        ${pkgs.coreutils}/bin/ln -sfv /run/current-system/sw/bin/bash /usr/bin/bash
      '';
      RemainAfterExit = true;
    };
  };


  system.activationScripts.diff = {
    supportsDryActivation = true;
    text = ''
      if [[ -e /run/current-system ]]; then
        ${lib.getExe pkgs.nushell} -c "
          let diff_closure = ${lib.getExe pkgs.nix} store diff-closures /run/current-system '$systemConfig';
          if \$diff_closure != \"\" {
            let table = \$diff_closure
            | lines
            | where \$it =~ KiB
            | where \$it =~ →
            | parse -r '^(?<Package>\S+): (?<Old_Version>[^,]+)(?:.*) → (?<New_Version>[^,]+)(?:.*, )(?<DiffBin>.*)$'
            | insert Diff {
              get DiffBin
              | ansi strip
              | str trim -l -c '+'
              | into filesize
            }
            | reject DiffBin
            | sort-by -r Diff; print \$table; \$table
            | math sum
          }
        "
      fi
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
    btdu
    ldp
    xdg-desktop-portal
  ];
}
