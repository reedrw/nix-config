{ config, lib, pkgs, ... }:

{
  services.mullvad-vpn = {
    enable = lib.mkDefault true;
    package = pkgs.mullvad-vpn;
  };

  systemd.services.mullvad-daemon = {
    after = [
      "nix-daemon.service"
    ] ++ lib.optionals config.services.tailscale.enable ["tailscaled.service"];
    preStart = ''
      sleep 5
    '';
    postStart = let
      mullvad = config.services.mullvad-vpn.package;
    in ''
      while ! ${mullvad}/bin/mullvad status >/dev/null; do sleep 1; done
      ${mullvad}/bin/mullvad lan set allow
      ${mullvad}/bin/mullvad auto-connect set on
      ${mullvad}/bin/mullvad split-tunnel add "$(${pkgs.procps}/bin/pidof nix-daemon)"
    '' + lib.optionalString config.services.tailscale.enable ''
      ${mullvad}/bin/mullvad split-tunnel add "$(${pkgs.procps}/bin/pidof tailscaled)";
    '';
  };

  # This is how I access mullvad in Firefox, allowing me to use the
  # foxyproxy extension to switch between mullvad and my normal
  # connection and set per-domain rules.
  services.autossh.sessions = let
    mullvadEnabled = config.services.mullvad-vpn.enable;
  in lib.optionals mullvadEnabled [{
    extraArguments = "-D 1337 -nNT localhost";
    name = "mullvad-socks-proxy";
    user = "reed";
  }];
}
