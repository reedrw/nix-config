{ pkgs, lib, config, ... }:

{
  systemd.user.services = with config.lib.functions;
  lib.mergeAttrsList [
    (mkSimpleService "updog" (
      builtins.readFile ./updog.sh |>
      pkgs.writeNixShellScript "updog" |>
      lib.getExe
    ))
    (lib.recursiveUpdate
      (mkSimpleService "autossh-updog-tuns" (
        pkgs.writeShellScript "autossh-updog-tuns" ''
          set -x
          autossh="${lib.getExe pkgs.autossh}"
          if [[ -f /run/wrappers/bin/mullvad-exclude ]]; then
            autossh="/run/wrappers/bin/mullvad-exclude $autossh"
          fi
          $autossh -M 0 -R updog:80:localhost:9090 tuns.sh
        ''
      )) {
        autossh-updog-tuns.Service.ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      }
    )
  ];


  home.packages = with pkgs; [
    updog
    (writeShellScriptBin "shareurl" ''
      UPDOG_PASSWORD=""
      if test -f ~/.cache/updog-password; then
        UPDOG_PASSWORD="$(cat ~/.cache/updog-password)"
      else
        echo "password file missing"
        exit 1
      fi

      url="https://user:$UPDOG_PASSWORD@reedrw-updog.tuns.sh"

      if test -p /dev/stdout; then
        echo "$url"
      else
        echo "~/files/share is being shared to"
        echo "$url"
      fi

    '')
  ];
}
