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
      theme = "dark-ansi";
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

          ## Proactive tool use

          Never ask for information that a tool can fetch. Before asking the user a clarifying question, check whether a tool can answer it instead:

          - **URLs in the conversation** — always fetch them with WebFetch rather than saying you can't access external sites or asking the user to describe the page.
          - **System/hardware info** — use Bash (`lspci`, `/sys/class/drm/`, `uname`, `cat /proc/cpuinfo`, etc.) or `nix eval` before asking "what GPU/CPU/kernel do you have?"
          - **Installed packages or config values** — query with `nix eval` before asking what's installed or enabled.
          - **File contents** — read the file before asking the user to paste it.

          The pattern to avoid: responding with "I don't know X, could you tell me?" when a tool call would answer the question in seconds.
        '';
      };
    };
  };

  custom.persistence = {
    files = [ ".claude.json" ];
    directories = [
      ".claude"
      ".config/opencode"
      ".cache/opencode"
      ".local/share/opencode"
      ".local/state/opencode"
    ];
  };
}
