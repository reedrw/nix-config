{ pkgs, ... }:

{
  # amd-pstate-epp: keep the "powersave" governor (recommended with EPP).
  # balance_performance: cores still deep-idle (RAPL pkg ~32mW) but ramp up
  # quickly on bursty interactive loads; balance_power was noticeably
  # slower to ramp. Do NOT use "performance" — it pins cores high while
  # barely loaded and cost ~2x idle power at some point.
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
          echo balance_performance > "$cpu/energy_performance_preference"
        done
      '';
    };
  };
}
