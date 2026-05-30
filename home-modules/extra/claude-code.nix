{ config, pkgs, lib, ... }:
let
  cfg = config.programs.claude-code;
in
{
  programs.claude-code = {
    enable = true;
    settings = {
      theme = if config.stylix.polarity == "light" then "light-ansi" else "dark-ansi";
      permissions = { allow = [ "Read(/nix/store/**)" ]; };
    };
    package = pkgs.wrapPackage pkgs.claude-code (binPath: ''
      #! ${pkgs.runtimeShell}
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
      exec ${binPath} "$@"
    '');
    mcpServers.nixos = {
      type = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
  };

  home.file."${cfg.configDir}/settings.json".enable = false;

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

      Claude Code is configured via the home-manager module at `home-modules/extra/claude-code.nix` inside the nix-config repo at `${pkgs.flakePath}`. Any changes to Claude Code settings, environment, permissions, or behavior must be made there — not by editing global Claude config files directly.
    '';
  };

  custom.persistence = {
    files = [ ".claude.json" ];
    directories = [ ".claude" ];
  };
}
