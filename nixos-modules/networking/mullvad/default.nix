{ config, lib, pkgs, ... }:
let
  mullvadEnabled = config.services.mullvad-vpn.enable;
in
{
  services.mullvad-vpn = {
    enable = lib.mkDefault true;
    package = pkgs.mullvad-vpn;

  # mullvad-vpn currently repackages a prebuilt .deb (built without
  # --features cgroup2), so the daemon falls back to mounting a cgroupv1
  # net_cls controller for split-tunneling. That hybrid /proc/<pid>/cgroup
  # breaks polkit's parser — see pkgs/patches/polkit/INVESTIGATION.md.
  #
  # Once https://github.com/NixOS/nixpkgs/issues/521059 lands (mullvad-vpn
  # built from source), uncomment the override below to enable cgroupv2
  # split-tunneling and drop polkit/cgroup-hybrid-parse.patch
  # (plus the corresponding lines in nixos-modules/core/run0/default.nix).
  #
  # package = pkgs.mullvad-vpn.overrideAttrs (old: {
  #   cargoBuildFeatures = (old.cargoBuildFeatures or [ ]) ++ [
  #     "mullvad-daemon/cgroup2"
  #     "mullvad-exclude/cgroup2"
  #   ];
  # });
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
  services.autossh.sessions = lib.optionals mullvadEnabled [{
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

  # polkit's get_cgroupid_for_pidfd assumes pure cgroupv2 in /proc/<pid>/cgroup.
  # mullvad-daemon (nixpkgs build) mounts a cgroupv1 net_cls controller for
  # split-tunneling because the upstream `cgroup2` Cargo feature flag isn't
  # enabled; that gives every process a hybrid /proc/<pid>/cgroup, the parser
  # picks the wrong line, and AUTH_ADMIN_KEEP never reuses a cached authz.
  # See pkgs/patches/polkit/INVESTIGATION.md for the full walkthrough.
  # This patch can be dropped once mullvad-vpn is built from source in nixpkgs
  # and we enable `cgroup2` on it — see pkgs/alias.nix and
  # https://github.com/NixOS/nixpkgs/issues/521059.
  security.polkit.package = if mullvadEnabled then pkgs.polkit.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./cgroup-hybrid-parse.patch
    ];
  }) else pkgs.polkit;

  custom.persistence.directories = [
    "/etc/mullvad-vpn"
  ];
}
