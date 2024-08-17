{ config, osConfig, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
in
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv = {
      enable = true;
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.tmux = {
    enable = true;
    extraConfig = ''
      set -g status off
      set -g destroy-unattached on
      set -g mouse on
      set -g default-terminal 'tmux-256color'
      set -ga terminal-overrides ',kitty:RGB'
      set -s escape-time 0
      set -g history-limit 10000
      set -g allow-passthrough on
      # set -g popup-border-lines none
    '';
  };

  # We set ZDOTDIR at system level, so we don't need
  # to bootstrap the the zsh environment like this.
  home.file.".zshenv".enable = false;

  programs.zsh = let
    mkZshPlugin = { pkg, file ? "${pkg.pname}.plugin.zsh" }: {
      name = pkg.pname;
      src = pkg.src;
      inherit file;
    };
  in
  {
    enable = true;
    dotDir = ".local/share/zsh";
    plugins = with pkgs; [
      (mkZshPlugin { pkg = zsh-autosuggestions; })
      (mkZshPlugin {
        pkg = zsh-fzf-tab;
        file = "fzf-tab.plugin.zsh"; })
      (mkZshPlugin { pkg = zsh-syntax-highlighting; })
    ] ++ lib.attrsets.mapAttrsToList (name: src: {
      inherit name src;
    }) sources;
    autocd = true;
    defaultKeymap = "emacs";
    history = {
      save = 99999;
      size = 99999;
    };
    initExtra =
    with pkgs;
    with config.lib.stylix.scheme;
    ''
      while read -r i; do
        autoload -Uz "$i"
      done << EOF
        add-zsh-hook
        colors
        down-line-or-beginning-search
        up-line-or-beginning-search
      EOF

      while read -r i; do
        setopt "$i"
      done << EOF
        interactivecomments
        histverify
      EOF

      unsetopt nomatch

      source ${oh-my-zsh.src}/lib/async_prompt.zsh
      source ${oh-my-zsh.src}/lib/git.zsh
      source ${oh-my-zsh.src}/plugins/sudo/sudo.plugin.zsh
      source ${ranger.src}/examples/shell_automatic_cd.sh 2> /dev/null

      export NIX_PATH=$XDG_STATE_HOME/nix/defexpr/channels:/nix/var/nix/profiles/per-user/root/channels''${NIX_PATH:+:$NIX_PATH}

      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      colors
      setopt promptsubst
      PROMPT='%{$fg_bold[blue]%}%(!.%d.%~)%{$reset_color%} $(git_prompt_info) %(?..%{%K{#${base02}}%F{red}%}!%?%{$reset_color%} )%(!.#.$) '

      # show hostname if in ssh session
      if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$DISTROBOX_ENTER_PATH" ]; then
        PROMPT="%(!.%{%F{red}%}.%{%F{green}%})%n%{$reset_color%}@%{%F{magenta}%}%M $PROMPT"
      else
        PROMPT="%(!.%{%F{red}%}.%{%F{green}%})%n%{$reset_color%} $PROMPT"
      fi

      PROMPT_ORIG=$PROMPT

      ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg[yellow]%}git:"
      ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%})"
      ZSH_THEME_GIT_PROMPT_DIRTY=" *"
      ZSH_THEME_GIT_PROMPT_CLEAN=""

      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#${base02}"
      ZSH_AUTOSUGGEST_STRATEGY="completion"
      ZSH_AUTOSUGGEST_USE_ASYNC="yes"

      export MANPAGER="nvim +Man\!"
      export EDITOR="${config.home.sessionVariables.EDITOR}"

      # Make sure nix-shell gets its completions loaded
      # BUG: Doesn't unload completions when leaving direnv
      function set-completions-from-path() {
        local old_fpath_len=''${#fpath}
        local fpath_union=("''${(@)fpath}")
        typeset -U fpath_union

        fpath=()
        for p in "''${(@)path}"; do
          if [[ "$p" == /nix/store/* ]]; then
            fpath+="$p"/../share/zsh/site-functions
          fi
        done
        fpath+=("''${(@)fpath_backup}")

        fpath_union+=("''${(@)fpath}")
        if [[ "''${#fpath}" -ne "$old_fpath_len" || ''${#fpath_union} -ne "$old_fpath_len" ]] && [[ -n "$ANY_NIX_SHELL_PKGS" ]]; then
          compinit -D
        fi
      }

      fpath_backup=("''${(@)fpath}")
      add-zsh-hook precmd set-completions-from-path
      add-zsh-hook chpwd set-completions-from-path

      # Draw a horizontal line between commands
      first_command_sent=0
      line_not_drawn=1
      force_draw=0
      function draw-separator-line() {
        if [[ $first_command_sent -eq 1 || force_draw -eq 1 ]] && [[ $line_not_drawn -eq 1 ]]; then
          PROMPT=$'%{%F{#${base02}}%}%{\e(0%}''${(r:$COLUMNS::q:)}%{\e(B%}'$PROMPT
          line_not_drawn=0
        fi
        first_command_sent=1
      }

      function clear() {
        PROMPT="$PROMPT_ORIG"
        first_command_sent=0
        line_not_drawn=1
        force_draw=0
        command clear
      }

      add-zsh-hook precmd draw-separator-line

      FZF_TAB_FLAGS=(
        -i
        --ansi   # Enable ANSI color support, necessary for showing groups
        --color=16
        --layout=reverse
        --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
        --info=hidden
        --no-separator
      )

      FZF_DEFAULT_OPTS="$FZF_TAB_FLAGS"

      if [[ "$USER" != "root" ]] && [[ "$TMUX" == *"tmux"* ]]; then
        zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
      fi

      zstyle ':fzf-tab:*' fzf-flags $FZF_TAB_FLAGS

      zstyle ':completion:*' sort false
      zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm,cmd -w -w"

      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' menu select
      zstyle ':completion:*' special-dirs true
      zmodload zsh/complist

      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search

      unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
      unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND

      bindkey  "''${terminfo[kcuu1]}" up-line-or-beginning-search
      bindkey  "''${terminfo[kcud1]}" down-line-or-beginning-search
      bindkey '^[[1~' beginning-of-line
      bindkey '^[[4~' end-of-line

      # bind alt+shift+enter to open a new terminal in the current directory
      function termwwidget() { $TERMINAL &! }
      zle -N termwwidget
      bindkey '^[^M' termwwidget

      if [[ -f "${osConfig.custom.persistDir}/${config.xdg.dataHome}/zsh/zsh_history" ]]; then
        HISTFILE="${osConfig.custom.persistDir}/${config.xdg.dataHome}/zsh/zsh_history"
      else
        HISTFILE="$HOME/.zsh_history"
      fi

      function git(){
        case "$1" in
          ~)
            cd "$(command git rev-parse --show-toplevel)"
          ;;
          clone)
            ${gitAndTools.hub}/bin/hub clone --recurse-submodules "''${@:2}"
          ;;
          *)
            ${gitAndTools.hub}/bin/hub "$@"
          ;;
        esac
      }

      function touch(){
        for file in "$@"; do
          if [[ "$file" = */* ]]; then
            mkdir -p "''${file%/*}"
          fi;
          command touch "$file";
        done
      }

      function c(){
        if [[ -p /dev/stdin ]]; then
          xclip -i -selection clipboard
        else
          xclip -o -selection clipboard
        fi
      }
    '';
    shellAliases = with pkgs; {
      ":q" = "exit";
      "\\$" = "";
      bmount = lib.getExe bashmount;
      cat = "${lib.getExe bat} --theme=base16 --style='changes,snip,numbers' --paging=never --wrap=never";
      cd = "z";
      cp = "cp -riv";
      df = lib.getExe pydf;
      gcd = "sudo gc -d";
      ln = "ln -v";
      ls = "${lib.getExe eza} -lh --git -s type";
      mkdir = "mkdir -vp";
      mv = "mv -iv";
      nr = "nix repl ~/.config/nixpkgs";
      ping = "${lib.getExe prettyping} --nolegend";
      rm = "rm -v";
      rr = "ranger_cd";
      rsync = "rsync --old-args";
      snapper = "snapper -c persist";
      taskdone = "${libnotify}/bin/notify-send 'Task finished.' && exit";
      tb = "termbin";
      termbin = "nc termbin.com 9999";
      tree = "ls --tree";
      watch = lib.getExe viddy;
      wget = "${lib.getExe wget} --progress=dot:giga";
      x = "exit";
    };
  };
}
