{ config, lib, pkgs, ... }:

{
  services.mullvad-vpn = {
    enable = lib.mkDefault true;
    package = pkgs.mullvad-vpn;
  };

  systemd.services.mullvad-daemon = {
    after = [
      "nix-daemon.service"
    ] ++ lib.optionals config.services.tailscale.enable ["tailscaled.service"]
      ++ lib.optionals config.services.openssh.enable ["sshd.service"];
    preStart = ''
      sleep 5
    '';
    postStart = let
      mullvad = "${config.services.mullvad-vpn.package}/bin/mullvad";
    in ''
      while ! ${mullvad} status >/dev/null; do sleep 1; done
      ${mullvad} lan set allow
      ${mullvad} auto-connect set on
      ${mullvad} split-tunnel add "$(${pkgs.procps}/bin/pidof nix-daemon)"
    '' + lib.optionalString config.services.tailscale.enable ''
      ${mullvad} split-tunnel add "$(${pkgs.procps}/bin/pidof tailscaled)";
    '' + lib.optionalString config.services.openssh.enable ''
      ${mullvad} split-tunnel add "$(${pkgs.procps}/bin/pidof sshd)";
    '';
  };

  # This is how I access mullvad in Firefox, allowing me to use the
  # foxyproxy extension to switch between mullvad and my normal
  # connection and set per-domain exclusion rules.
  services.autossh.sessions = let
    mullvadEnabled = config.services.mullvad-vpn.enable;
  in lib.optionals mullvadEnabled [{
    extraArguments = "-D 1337 -nNT localhost";
    name = "mullvad-exclude-proxy";
    user = "reed";
  }];

  systemd.services.autossh-mullvad-exclude-proxy = {
    after = [
      "sshd.service"
      "mullvad-daemon.service"
    ];
  };
}
