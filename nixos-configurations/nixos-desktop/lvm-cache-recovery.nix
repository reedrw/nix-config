# Post-crash recovery for the lvmcache-backed root volume (vg01/nixos).
#
# After an unclean shutdown, dm-cache flags the pool "needs check" and the
# event-based auto-activation used by stage-1 (pvscan --cache -aay) may
# decline to activate the LV, leaving stage-1 waiting on /dev/vg01/nixos
# until the device timeout expires and the boot fails. A manual
# `vgchange -ay` activates the exact same state (verified during the
# 2026-09-27 recovery from the live ISO), so retry it in parallel with
# the device wait until the device node shows up. If the LV still is not
# up after the loop (~60s, within the stock 90s device timeout), something
# is wrong enough to warrant manual intervention anyway.
{ config, pkgs, ... }:

{
  boot.initrd.systemd.services.vg01-activate-retry = {
    description = "Retry manual activation of vg01 (post-crash fallback)";
    wantedBy = [ "sysinit.target" ];
    after = [ "systemd-modules-load.service" "systemd-udev-trigger.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Use the .bin output: stage-1 already ships it in the initrd.
      ExecStart = pkgs.writeShellScript "vg01-activate-retry" ''
        for i in $(seq 1 30); do
          [ -e /dev/vg01/nixos ] && exit 0
          ${pkgs.lvm2.bin}/bin/lvm vgchange -ay vg01 2>/dev/null || true
          sleep 2
        done
        exit 0
      '';
    };
  };

  boot.initrd.systemd.storePaths = [
    # The initrd only ships what is listed here; without this the
    # ExecStart script would be referenced by the unit but absent
    # from the initrd (status=203/EXEC).
    config.boot.initrd.systemd.services.vg01-activate-retry.serviceConfig.ExecStart
  ];
}
