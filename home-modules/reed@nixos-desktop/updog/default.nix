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
          ${lib.getExe pkgs.autossh} -M 0 -R updog:80:localhost:9090 tuns.sh
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
      if test -f /tmp/updog-password; then
        UPDOG_PASSWORD="$(cat /tmp/updog-password)"
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
