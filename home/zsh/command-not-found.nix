{ config, inputs, pkgs, ... }:
let
  dbPath = "/nix/var/nix/profiles/per-user/root/channels/nixos/programs.sqlite";
  commandNotFound = pkgs.substituteAll {
    name = "command-not-found";
    dir = "bin";
    src = "${inputs.nixpkgs.outPath}/nixos/modules/programs/command-not-found/command-not-found.pl";
    isExecutable = true;
    inherit dbPath;
    perl = pkgs.perl.withPackages (p: [ p.DBDSQLite p.StringShellQuote ]);
  };
  inherit (config.lib.stylix) scheme;
in
with pkgs; ''
  if [ -n "$ANY_NIX_SHELL_PKGS" ]; then
    if [ -n "$IN_AUTO_SHELL" ]; then
      alias leave="noglob exit"
      alias exit="kill -9 $(ps -o ppid="" | sed -n 2p | xargs)"
      color="yellow"
    else
      color="green"
    fi
    # if [ "''${#''${=ANY_NIX_SHELL_PKGS}}" -gt 1 ]; then
    #   RPROMPT="%{$fg_bold[$color]%}▐%K{236}''${ANY_NIX_SHELL_PKGS} %{$reset_color%}"
    # else
    #   RPROMPT="%K{$color}%{$fg_bold[black]%} nix-shell %K{236}%{$fg_bold[$color]%}$ANY_NIX_SHELL_PKGS %{$reset_color%}"
    # fi
    RPROMPT="%K{$color}%{$fg_bold[black]%} nix-shell %K{#${scheme.base02}}%{$fg_bold[$color]%}$ANY_NIX_SHELL_PKGS %{$reset_color%}"
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
      attr="$(${nix-index}/bin/nix-locate --db "$database" --top-level --minimal --at-root --whole-name "/bin/$argv0")"

      if [[ -z $attr ]]; then
        >&2 echo "$argv0: command not found"
        return 127
      fi

      attr="$(echo "$attr" | ${lib.getExe fzf} --color=16 --layout=reverse --info=hidden --height 40%)" || return 130
      attr="''${attr%.*}"

      export ANY_NIX_SHELL_PKGS="$ANY_NIX_SHELL_PKGS $attr"
      export IN_AUTO_SHELL="yes"
      __nix shell "unstable#$attr" -c sh -c "$argv0 $*; >&2 exec zsh"
    fi
  }

  __nix-shell(){
    ${any-nix-shell}/bin/.any-nix-shell-wrapper zsh "$@"
  }

  nix-shell(){
    unset IN_AUTO_SHELL
    __nix-shell "$@"
  }

  __nix(){
    if [[ $1 == shell ]]; then
      shift
      ${any-nix-shell}/bin/.any-nix-wrapper zsh "$@"
    else
      command nix "$@"
    fi
  }

  nix() {
    unset IN_AUTO_SHELL
    __nix "$@"
  }
''
