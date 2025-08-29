{ config, pkgs, inputs, lib, ... }:
let
  dbPath = "/nix/var/nix/profiles/per-user/root/channels/nixos/programs.sqlite";
  commandNotFound = pkgs.replaceVarsWith {
    name = "command-not-found";
    dir = "bin";
    src = "${inputs.nixpkgs}/nixos/modules/programs/command-not-found/command-not-found.pl";
    isExecutable = true;
    replacements = {
      inherit (config.programs.command-not-found) dbPath;
      perl = pkgs.perl.withPackages (p: [
        p.DBDSQLite
        p.StringShellQuote
      ]);
    };
  };

  inherit (config.lib.stylix) colors;
in
{
  programs.zsh.initContent = lib.mkAfter ''
    if [ -n "$ANY_NIX_SHELL_PKGS" ]; then
      if [ -n "$IN_AUTO_SHELL" ]; then
        alias leave="noglob exit"
        alias exit="kill -9 $(ps -o ppid="" | sed -n 2p | xargs)"
        color="yellow"
        force_draw=1
      else
        color="green"
      fi
      RPROMPT="%K{$color}%{$fg_bold[black]%} nix-shell %K{#${colors.base02}}%{$fg_bold[$color]%}$ANY_NIX_SHELL_PKGS %{$reset_color%}"
    fi
    command_not_found_handler(){
      # If user is root, use the default handler
      # AUTO_NIX_SHELL doesn't work with sudo. Hangs forever.
      if [[ $UID -eq 0 ]]; then

        local p='${commandNotFound}/bin/command-not-found'
        if [ -x "$p" ] && [ -f '${dbPath}' ]
        then
          "$p" "$@"
          if [ $? = 126 ]
          then
            "$@"
          else
            return 127
          fi
        else
          echo "$1: command not found" >&2
          return 127
        fi

      else
        if [ -f "$HOME/.cache/nix-index/files" ]; then
          database="$HOME/.cache/nix-index"
        else
          >&2 echo 'No database.'
          return 1
        fi

        argv0=$1; shift
        attr="$(${pkgs.nix-index}/bin/nix-locate --db "$database" --minimal --at-root --whole-name "/bin/$argv0")"

        if [[ -z $attr ]]; then
          >&2 echo "$argv0: command not found"
          return 127
        fi

        attr="$(echo "$attr" | ${lib.getExe pkgs.fzf} --layout=reverse --info=hidden --height 40%)" || return 130
        attr="''${attr%.*}"

        export ANY_NIX_SHELL_PKGS="$ANY_NIX_SHELL_PKGS $attr"
        export IN_AUTO_SHELL="yes"
        timeout 0.25 nix eval "nixpkgs#$attr" 2> /dev/null
        if [[ "$?" -eq 124 ]]; then
          branch="nixpkgs"
        else
          branch="unstable"
        fi

        if [ -f "$HOME/.cache/nix/comma-runcounts" ]; then
          # shellcheck disable=1091
          source "$HOME/.cache/nix/comma-runcounts"
        else
          declare -A usage_counts
        fi

        if test -v "usage_counts[$attr]"; then
          (( usage_counts[$attr]++ ))
          if [ "''${usage_counts[$attr]}" -gt 4 ]; then
            unset "usage_counts[$attr]"
            nix profile install "$branch#$attr"
          fi
        else
          usage_counts[$attr]=1
        fi

        declare -p usage_counts > "$HOME/.cache/nix/comma-runcounts"
        unset usage_counts

        __nix shell "$branch#$attr" -c sh -c "$argv0 $*; >&2 exec zsh"
      fi
    }

    __nix-shell(){
      ${pkgs.any-nix-shell}/bin/.any-nix-shell-wrapper zsh "$@"
    }

    nix-shell(){
      unset IN_AUTO_SHELL
      __nix-shell "$@"
    }

    __nix(){
      if [[ $1 == shell ]]; then
        ${pkgs.any-nix-shell}/bin/.any-nix-wrapper zsh "$@"
      else
        command nix "$@"
      fi
    }

    nix() {
      unset IN_AUTO_SHELL
      __nix "$@"
    }
  '';
}
