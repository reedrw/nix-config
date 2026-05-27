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
      set -x
      while ! ${mullvad} status >/dev/null; do sleep 1; done
      ${mullvad} lan set allow
      ${mullvad} auto-connect set on
    '' + lib.optionalString config.services.tailscale.enable ''
      ${mullvad} split-tunnel add "$(${pkgs.procps}/bin/pidof tailscaled)";
    '' + lib.optionalString config.services.openssh.enable ''
      ${mullvad} split-tunnel add "$(${pkgs.procps}/bin/pidof sshd)";
    '' + ''set +x'';
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

  # Tailscale's `ip mangle OUTPUT` rule clobbers mullvad's split-tunnel
  # ct mark (mole fwmark 0x6d6f6c65 collides with tailscale's 0x00ff0000
  # mask), which breaks mullvad-exclude. Restore it after tailscale runs.
  networking.nftables.tables.mullvadTailscaleFix = lib.mkIf config.services.tailscale.enable {
    enable = true;
    family = "inet";
    content = ''
      chain restoreExcludeCtMark {
        type filter hook output priority -100; policy accept;
        meta mark 0x6d6f6c65 ct mark set 0x00000f41;
      }
    '';
  };

  custom.persistence.directories = [
    "/etc/mullvad-vpn"
  ];
}
