{ pkgs, lib, ...}:
let
  updateScript = pkgs.writeShellApplication rec {
    name = "updateScript";
    meta.mainProgram = name;
    runtimeInputs = with pkgs; [ git ldp coreutils ];
    text = ''
      set -x
      sleep 120

      export PATH="/run/wrappers/bin:$PATH"
      export PATH="/run/current-system/sw/bin:$PATH"

      git(){
        su reed -c "git $*"
      }

      pushd ${pkgs.flakePath}
        git fetch
        if [[ -z "$(git status -s)" ]] \
        && [[ -z "$(git log origin/main..HEAD)" ]] \
        && [[ "$(git log HEAD..origin/main | wc -l)" -gt 0 ]];
        then
          git pull
          ldp -v
        fi
      popd
    '';
  };
in
{
  systemd.timers.autoUpdate = {
    enable = true;
    description = "Update the system every night";
    timerConfig = {
      Unit = "autoUpdate.service";
      WakeSystem = true;
      Persistent = false;
      OnCalendar = "*-*-* 03:00:00";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.autoUpdate = {
    enable = true;
    description = "Update the system";
    unitConfig = {
      Wants = "network-online.target";
      After = "network-online.target";
      ConditionACPower = true;
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "systemd-inhibit --what=handle-lid-switch --why=update ${lib.getExe updateScript}";
    };
  };
}
