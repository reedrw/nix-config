{ pkgs, lib, config, ... }:

{
  systemd.user.services = config.lib.functions.mkSimpleService "updog" (
    builtins.readFile ./updog.sh |>
    pkgs.writeNixShellScript "updog" |>
    lib.getExe
  );

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
