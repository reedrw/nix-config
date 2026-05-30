{ config, pkgs, lib, ... }:
let
  cfg = config.programs.claude-code;

  statuslineScript = pkgs.writeNixShellScript "claude-statusline"
    (builtins.readFile ./claude-statusline.sh);

    writeConfig = pkgs.writeShellScript "write-claude-config.sh" ''
      PATH="${lib.makeBinPath [ pkgs.jq ]}:$PATH"
      settings="${cfg.configDir}/settings.json"
      mkdir -p "${cfg.configDir}"
      if [ -f "$settings" ]; then
        tmp="$(jq -r '${lib.concatStringsSep "|" (lib.mapAttrsToList (n1: v1:
          ".${n1}=${builtins.toJSON v1}"
        ) cfg.settings)}' \
          "$settings"
        )" && cat <<< "$tmp" > "$settings"
      else
        [ -L "$settings" ] \
          && rm "$settings" \
        echo '${builtins.toJSON cfg.settings}' > "$settings"
      fi
      chmod 644 "$settings"
    '';
in
{
  programs.claude-code = {
    enable = true;
    settings = {
      theme = if config.stylix.polarity == "light" then "light-ansi" else "dark-ansi";
      autoMemoryEnabled = false;
      permissions = { allow = [ "Read(/nix/store/**)" ]; };
      hooks = {
        Stop = [{
          hooks = [{
            type = "command";
            command = pkgs.writeShellScript "claude-notify-stop" ''
              exec ${pkgs.libnotify}/bin/notify-send "Claude Code" "Waiting for input"
            '';
          }];
        }];
        Notification = [{
          hooks = [{
            type = "command";
            command = pkgs.writeShellScript "claude-notify-attention" ''
              exec ${pkgs.libnotify}/bin/notify-send "Claude Code" "Attention needed"
            '';
          }];
        }];
      };
      statusLine = {
        type = "command";
        command = "${statuslineScript}/bin/claude-statusline";
      };
    };
    package = pkgs.wrapPackage pkgs.claude-code (binPath: ''
      #! ${pkgs.runtimeShell}
      ${writeConfig}
      exec ${binPath} "$@"
    '');
    mcpServers.nixos = {
      type = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
  };

  home.file."${cfg.configDir}/settings.json".enable = false;

  home.activation.claudeCodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${writeConfig}
  '';

  home.file.".claude/memory/feedback_nix_config_first.md" = {
    force = true;
    text = ''
      ---
      name: All config goes through Nix
      description: All system and user configuration on this machine is managed declaratively via nix-config — never edit config files directly
      type: feedback
      ---

      Nearly all configuration on this machine is managed through the nix-config repo at `${pkgs.flakePath}`. Before editing any config file directly, check whether it is (or should be) managed by a NixOS or home-manager module first.

      **Why:** The system uses impermanence — direct edits to config files may be wiped on reboot. Declarative Nix config is the only durable place to make changes.

      **How to apply:** When asked to configure anything (a tool, a service, a dotfile, a system setting), default to writing or editing the appropriate module in nix-config rather than touching the live file.
    '';
  };

  home.file.".claude/memory/reference_claude_code_config.md" = {
    force = true;
    text = ''
      ---
      name: Claude Code config location
      description: Where to edit Claude Code's own configuration — in the nix-config repo, not global config files
      type: reference
      ---

      Claude Code is configured via the home-manager module at `home-modules/extra/claude-code/default.nix` inside the nix-config repo at `${pkgs.flakePath}`. Any changes to Claude Code settings, environment, permissions, or behavior must be made there — not by editing global Claude config files directly.
    '';
  };

  home.file.".claude/memory/feedback_nix_flake_git_staging.md" = {
    force = true;
    text = ''
      ---
      name: Nix Flake Git Staging Requirement
      description: Nix flakes only read files that are staged (git add) in the git tree — untracked files are invisible to nix commands
      type: feedback
      ---

      Newly created (untracked) files must be staged with `git add` before Nix will see them in a flake. Modifications to already-tracked files are picked up automatically — no staging needed for edits.

      **Why:** Nix flakes use the git index to determine which files are part of the flake source, so brand-new files that have never been staged simply don't exist from Nix's perspective.

      **How to apply:** After creating a new file, remind the user to `git add` it before running any `nix` evaluation commands. Don't do this for edits to existing files — those are fine without staging.
    '';
  };

  home.file.".claude/memory/feedback_no_rec.md" = {
    force = true;
    text = ''
      ---
      name: Avoid rec keyword; prefer self-referencing function
      description: Don't use rec in Nix; try passing a self-referencing function first
      type: feedback
      ---

      Avoid the `rec` keyword in Nix. Many build functions (including `buildPythonPackage`, `buildPythonApplication`, and others) natively accept a function argument `(self: { ... })` for self-reference. Try that first before reaching for `rec` or `lib.fix`.

      **Why:** The self-referencing function pattern is cleaner and more idiomatic; `rec` can cause subtle issues with overrides.

      **How to apply:** Any time self-reference is needed in a derivation attrset (e.g. `inherit pname version` in `src`), write `buildFoo (self: { pname = "..."; src = use self.pname; })` instead of `buildFoo rec { pname = "..."; src = use pname; }`. Only fall back to `lib.fix` if the function doesn't natively support it.
    '';
  };

  home.file.".claude/memory/feedback_nix_inline_derivations.md" = {
    force = true;
    text = ''
      ---
      name: nix-inline-derivations
      description: Don't extract let bindings for values used in only one place; pass derivations inline and rely on Nix string coercion
      type: feedback
      ---

      Don't hoist a `let` binding just because a value is a derivation. If it's only used in one spot, write it inline at the point of use.

      Derivations coerce to their store path in string contexts — including inside `builtins.toJSON` — so `builtins.toString` is unnecessary. Just pass the derivation directly as the attribute value and let Nix coerce it.

      **Why:** Unnecessary `let` bindings add indirection without benefit when the value is only referenced once.

      **How to apply:** When writing a `pkgs.writeShellScript` (or similar) for a single-use command, write it inline as the attribute value rather than binding it at the top of the file.
    '';
  };

  custom.persistence = {
    files = [ ".claude.json" ];
    directories = [ ".claude" ];
  };
}
