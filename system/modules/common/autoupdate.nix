{ pkgs , ...}:
let
  updateScript = pkgs.writeShellApplication {
    name = "updateScript";
    runtimeInputs = with pkgs; [ git ldp coreutils ];
    text = ''
      set -x
      git(){
        /run/wrappers/bin/su reed -c "git $*"
      }
      pushd ${pkgs.flakePath}
        git fetch
        if [[ -z "$(git status -s)" ]] \
        && [[ -z "$(git log origin/master..HEAD)" ]] \
        && [[ "$(git log HEAD..origin/master | wc -l)" -gt 0 ]];
        then
          git pull
          ldp --boot
        fi
      popd
    '';
  };
in
{
  systemd.timers = {
    autoUpdate = {
      enable = true;
      description = "Update the system every night";
      timerConfig = {
        Unit = "autoUpdate.service";
        WakeSystem = true;
        Persistent = false;
        OnCalendar = "*-*-* 00:35";
      };
      wantedBy = [ "timers.target" ];
    };
  };

  systemd.services = {
    autoUpdate = {
      enable = true;
      description = "Update the system";
      unitConfig = {
        Wants = "network-online.target";
        After = "network-online.target";
        ConditionACPower = true;
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${updateScript}/bin/updateScript";
      };
    };
  };
}
