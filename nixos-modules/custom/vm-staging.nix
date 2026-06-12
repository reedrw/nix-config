{ config, lib, pkgs, ... }:
let
  cfg = config.custom.vmStaging;
in
{
  options.custom.vmStaging = {
    enable = lib.mkEnableOption ''
      VM staging mode. Makes a NixOS host agent-driveable inside QEMU:
      SSH on port 22, auto-login to the configured graphical session,
      VM-hostile services forced off, lockscreen disabled, qemu-guest
      tools enabled. Intended for the `nixos-vm`/`nixos-vm-sway` hosts
      that exist as test beds for the i3 → sway migration.
    '';

    user = lib.mkOption {
      type = lib.types.str;
      default = "reed";
      description = "Which user the agent SSHes in as and auto-logs into.";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "vm";
      description = ''
        Plain-text password for the staging user. This VM is dev-local
        and only reachable on localhost via QEMU port forward, so a
        weak fixed password is fine. Override per-host if you want to
        rotate.
      '';
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Extra SSH public keys to install for the staging user. Use
        this if you want passwordless agent access — populate from
        e.g. `builtins.readFile ~/.ssh/id_ed25519.pub` (requires
        --impure) or check a pubkey into the repo.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      password = lib.mkForce cfg.password;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    # mutableUsers must be true for the password override to apply on
    # hosts that normally set it false (nixos-desktop, nixos-t480).
    users.mutableUsers = lib.mkForce true;

    # Passwordless sudo so the agent can rebuild from within the VM.
    security.sudo.wheelNeedsPassword = lib.mkForce false;

    services = {
      # --- SSH for the agent ---------------------------------------------
      openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PasswordAuthentication = true;
          PermitRootLogin = "no";
          # Override the hardened MAC list from extra/sshd.nix so a stock
          # client connects without special config.
          Macs = lib.mkForce [
            "hmac-sha2-512-etm@openssh.com"
            "hmac-sha2-256-etm@openssh.com"
            "umac-128-etm@openssh.com"
            "hmac-sha2-256"
            "hmac-sha2-512"
          ];
        };
      };

      # --- Auto-login to the graphical session ---------------------------
      displayManager.autoLogin = {
        enable = true;
        inherit (cfg) user;
      };

      # --- QEMU guest niceties ------------------------------------------
      qemuGuest.enable = true;
      spice-vdagentd.enable = true;

      # --- Disable things that break or matter in a snapshot VM ----------
      btrfs.autoScrub.enable = lib.mkForce false;
      fstrim.enable          = lib.mkForce false;
    };

    # --- Screenshot tooling for both X11 and Wayland sessions ------------
    # vm-screenshot-grab picks the right backend for whichever session
    # is up. Agents call it via `ssh ... vm-screenshot-grab > out.png`.
    environment.systemPackages = with pkgs; [
      grim
      slurp
      wl-clipboard
      scrot
      maim
      xdotool
      (writeShellScriptBin "vm-screenshot-grab" ''
        set -eu
        if pgrep -x sway >/dev/null 2>&1; then
          for candidate in "$XDG_RUNTIME_DIR/wayland-1" "$XDG_RUNTIME_DIR/wayland-0"; do
            if [ -S "$candidate" ]; then
              export WAYLAND_DISPLAY="$(basename "$candidate")"
              break
            fi
          done
          # If the helper is run as a different user (e.g. via sudo from
          # the agent's ssh session), find reed's runtime dir.
          if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -S "/run/user/1000/wayland-1" ]; then
            export XDG_RUNTIME_DIR="/run/user/1000"
            export WAYLAND_DISPLAY="wayland-1"
          fi
          exec ${grim}/bin/grim -
        else
          export DISPLAY="''${DISPLAY:-:0}"
          export XAUTHORITY="''${XAUTHORITY:-/run/user/1000/gdm/Xauthority}"
          exec ${maim}/bin/maim --hidecursor
        fi
      '')
    ];

    # Don't lock-on-suspend (the script hard-codes X11 anyway and would
    # lock out the agent).
    systemd.services."lock-before-suspend".enable = lib.mkForce false;

    # Disable suspend so the agent's SSH session stays alive indefinitely.
    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowSuspendThenHibernate = "no";
      AllowHybridSleep = "no";
    };

    # Replace the lockProgram with a no-op so any keybind/service that
    # still calls it can't accidentally trap the agent.
    nixpkgs.overlays = [
      (_: prev: {
        lockProgram = prev.writeShellScriptBin "noop-lock" ''
          echo "vm-staging: lock disabled" >&2
          exit 0
        '';
      })
    ];
  };
}
