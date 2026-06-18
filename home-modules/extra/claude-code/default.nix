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
          && rm "$settings"
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
      skipAutoPermissionPrompt = true;
      showThinkingSummaries = true;
      hooks = {
        PreToolUse = [
          {
            matcher = "Bash";
            hooks = [{
              type = "command";
              command = pkgs.writeShellScript "claude-deny-nix-store-search" ''
                PATH="${lib.makeBinPath [ pkgs.jq pkgs.gnugrep ]}:$PATH"
                cmd=$(jq -r '.tool_input.command // empty')
                if [[ -n "$cmd" ]] && echo "$cmd" | grep -qE '^\s*(find|grep|egrep|fgrep|rg|awk|sed)\b' && echo "$cmd" | grep -qP '/nix/store(?!/[a-z0-9]{32}-)'; then
                  jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Searching /nix/store/ directly is not allowed - use nix eval to resolve store paths instead."}}'
                fi
              '';
            }];
          }
        ];
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
    mcpServers = {
      nixos = {
        type = "stdio";
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
      github = {
        type = "stdio";
        command = pkgs.writeShellScript "github-mcp-wrapper" ''
          PATH=${lib.makeBinPath [ pkgs.gh pkgs.github-mcp-server ]}
          export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null)"
          exec github-mcp-server stdio "$@"
        '';
      };
      context7 = {
        type = "stdio";
        command = "${pkgs.context7-mcp}/bin/context7-mcp";
      };
    };
  };

  stylix.targets.opencode.enable = true;

  programs.opencode.enable = true;

  home = {
    activation.claudeCodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${writeConfig}
    '';

    file = {
      "${cfg.configDir}/settings.json".enable = false;
      ".claude/CLAUDE.md" = {
        force = true;
        text = ''
          # Global Claude Code Instructions

          ## Machine configuration

          All system and user configuration on this machine is managed declaratively via the nix-config repo at `${pkgs.flakePath}`. Before editing any config file directly, check whether it is (or should be) managed by a NixOS or home-manager module first.

          The system uses impermanence — direct edits to config files may be wiped on reboot. Declarative Nix config is the only durable place to make changes.

          ## Querying machine config

          Prefer `nix eval` over reading source files to answer questions about what is configured:

          ```sh
          nix eval .#homeConfigurations."reed@nixos-desktop".config.home.packages --apply 'ps: map (p: p.name) ps' --json
          nix eval .#nixosConfigurations.nixos-desktop.config.services.openssh.enable
          nix eval .#nixosConfigurations.nixos-desktop.config.networking.hostName
          ```

          ## Nix conventions

          - **Git staging:** Nix flakes only read staged files — new files must be `git add`-ed before any `nix` command will see them. Edits to already-tracked files need no staging.
          - **Inline derivations:** Don't hoist `let` bindings for single-use derivations. Pass inline and let Nix string-coerce the store path — `builtins.toString` is not needed.
          - **New nix packages:** Default to a fresh project-local `flake.nix` from the flake-parts template. Only add to nix-config when you're already working inside it or the package is genuinely system-wide.

          ## Troubleshooting

          - When troubleshooting, don't make a commit until the fix has been validated by the user.
        '';
      };

      ".claude/commands/remember.md" = {
        force = true;
        text = ''
          ---
          description: Save a Claude Code behavior to memory at the appropriate scope
          ---

          The user wants you to remember: $ARGUMENTS

          ## Step 1: Hook or memory?

          First assess whether this is better implemented as a **hook** (automatic behavior triggered by an event) rather than a memory instruction.

          **Hook signals — the request describes something that should happen *automatically* when an event occurs:**
          - "after writing/editing files, do X" → PostToolUse hook (Write|Edit matcher)
          - "before/after running bash commands, do X" → Pre/PostToolUse hook (Bash matcher)
          - "when you stop, do X" → Stop hook
          - "before compacting, do X" → PreCompact hook
          - "every time a session starts, do X" → SessionStart hook
          - "when a tool/command fails, do X" → PostToolUseFailure hook

          **Memory signals — the request describes a standing preference, style, or instruction for Claude:**
          - Coding style or formatting preferences
          - Communication style or response format
          - Things to always avoid or always include
          - Project-specific context or conventions

          **If hook-suited:** use `AskUserQuestion` to confirm with the user before proceeding — explain that this sounds like it needs a hook in `settings.json` (not just memory, since memory cannot trigger automatic actions), and ask whether to set it up as a hook via `/update-config` or save it as a memory instruction anyway.

          **If memory-suited:** proceed to Step 2.

          ## Step 2: Scope

          This is always about how *Claude Code itself* should behave. There are exactly two scopes:

          1. **Universal (machine-level)** — applies whenever Claude Code is running on this machine, regardless of project. Add a concise bullet or sentence to the relevant section of `home.file.".claude/CLAUDE.md"` inside the Claude Code home-manager module in the nix-config repo at `${pkgs.flakePath}` (grep for `programs.claude-code`). **Never write directly to `~/.claude`.**

          2. **Repo-scoped** — applies only when Claude Code is working inside one specific repo. Written into that repo's `CLAUDE.md` (typically `<repo>/.claude/CLAUDE.md` or `<repo>/CLAUDE.md`).

          **If currently working inside the nix-config repo (`${pkgs.flakePath}`):** scope is ambiguous — pick the scope you think is correct, then **stop and confirm with the user via `AskUserQuestion` before writing anything**.

          **Otherwise:** default to universal (machine-level) and proceed without asking.

          After writing, if the change landed in nix-config (`${pkgs.flakePath}`), run `/ldp --switch` to apply.
        '';
      };
    };
  };

  custom.persistence = {
    files = [ ".claude.json" ];
    directories = [ ".claude" ".config/opencode" ".local/share/opencode" ];
  };
}
