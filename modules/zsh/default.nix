{ config, inputs, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
in
{
  programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv = {
        enable = true;
      };
    };

    dircolors = {
      enable = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    tmux = {
      enable = true;
    };
  };

  programs.zsh = let
    mkZshPlugin = { pkg, file ? "${pkg.pname}.plugin.zsh" }: {
      name = pkg.pname;
      src = pkg.src;
      inherit file;
    };
  in
  {
    enable = true;
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
    completionInit = "autoload -U compinit && compinit -i";
    history = {
      save = 99999;
      size = 99999;
    };
    initExtra = let
      inherit (config.colorScheme.colors) base02;
    in
    with pkgs;
    ''
      while read -r i; do
        autoload -Uz "$i"
      done << EOF
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

      source ${oh-my-zsh.src}/lib/git.zsh
      source ${oh-my-zsh.src}/plugins/sudo/sudo.plugin.zsh
      source ${ranger.src}/examples/shell_automatic_cd.sh 2> /dev/null

      export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels''${NIX_PATH:+:$NIX_PATH}

      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      colors
      setopt promptsubst
      PROMPT='%{$fg_bold[blue]%}%(!.%d.%~)%{$reset_color%} $(git_prompt_info) %(?..%{%K{236}%F{red}%}!%?%{$reset_color%} )%(!.#.$) '

      # show hostname if in ssh session
      if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$DISTROBOX_ENTER_PATH" ]; then
        PROMPT="%(!.%{%F{red}%}.%{%F{green}%})%n%{$reset_color%}@%{%F{magenta}%}%M $PROMPT"
      else
        PROMPT="%(!.%{%F{red}%}.%{%F{green}%})%n%{$reset_color%} $PROMPT"
      fi

      ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg[yellow]%}git:"
      ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%})"
      ZSH_THEME_GIT_PROMPT_DIRTY=" *"
      ZSH_THEME_GIT_PROMPT_CLEAN=""

      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#${base02}"
      ZSH_AUTOSUGGEST_STRATEGY="completion"
      ZSH_AUTOSUGGEST_USE_ASYNC="yes"

      export MANPAGER="nvim +Man\!"
      export EDITOR="${config.home.sessionVariables.EDITOR}"

      FZF_TAB_FLAGS=(
        -i
        --ansi   # Enable ANSI color support, necessary for showing groups
        --color=16
        --layout=reverse
        --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
        --info=hidden
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

      if [[ -f "/persist/home/$USER/.zsh_history" ]]; then
        HISTFILE="/persist/home/$USER/.zsh_history"
      else
        HISTFILE="$HOME/.zsh_history"
      fi

      bw-rofi-login(){
        ${keyutils}/bin/keyctl purge user bw_session
        ${bitwarden-cli}/bin/bw login
        ${keyutils}/bin/keyctl link @u @s
      }

      c(){
        [[ -p /dev/stdin ]] && \
          ${binPath xclip} -i -selection clipboard || \
          ${binPath xclip} -o -selection clipboard
      }

      git(){
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

      touch(){
        for file in "$@"; do
          if [[ "$file" = */* ]]; then
            mkdir -p "''${file%/*}"
          fi;
          command touch "$file";
        done
      }

    '' + import ./command-not-found.nix { inherit config inputs pkgs; };
    shellAliases = with pkgs; {
      ":q" = "exit";
      "\\$" = "";
      bmount = "${binPath bashmount}";
      cat = "${binPath bat} --theme=base16 --style='changes,grid,snip,numbers' --paging=never";
      cp = "cp -riv";
      df = "${pydf}/bin/pydf";
      gcd = "sudo gc -d";
      ln = "ln -v";
      ls = "${exa}/bin/exa -lh --git -s type";
      mkdir = "mkdir -vp";
      mv = "mv -iv";
      n = "cd ~/.config/nixpkgs";
      ping = "${binPath prettyping} --nolegend";
      rm = "rm -v";
      rr = "ranger_cd";
      rsync = "rsync --old-args";
      snapper = "snapper -c persist";
      taskdone = "${libnotify}/bin/notify-send 'Task finished.' && exit";
      tb = "termbin";
      termbin = "nc termbin.com 9999";
      tree = "ls --tree";
      watch = "${binPath viddy}";
      wget = "${binPath wget} --progress=dot:giga";
      x = "exit";
    };
  };
}
