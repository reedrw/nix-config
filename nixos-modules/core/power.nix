{ pkgs, ... }:

{
  # amd-pstate-epp: keep the "powersave" governor (recommended with EPP) and
  # set the energy-performance-preference so cores don't pin at ~5 GHz while
  # barely loaded (was costing ~2x idle power). Under real load, boosting
  # behavior is unaffected.
  powerManagement.cpuFreqGovernor = "powersave";

  systemd.services.cpu-epp = {
    description = "Set CPU energy-performance-preference";
    after = [ "cpufreq.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionVirtualization = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "set-epp" ''
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
          echo balance_power > "$cpu/energy_performance_preference"
        done
      '';
    };
  };
}
