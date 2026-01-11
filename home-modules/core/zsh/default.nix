{ config, lib, pkgs, util, ... }:
let
  sources = (util.importFlake ./plugins).inputs or {};
in
{
  imports = [
    sources.direnv-instant.homeModules.direnv-instant
    ({
      programs.direnv = {
        enable = true;
        nix-direnv = {
          enable = true;
        };
        config = {
          hide_env_diff = true;
          load_dotenv = true;
        };
      };

      programs.direnv-instant = {
        enable = true;
        package = sources.direnv-instant.packages."${pkgs.stdenv.hostPlatform.system}".default;
      };

      custom.persistence.directories = [
        ".local/share/direnv"
      ];
    })
    ({
      programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
      };

      custom.persistence.directories = [
        ".local/share/zoxide"
      ];
    })
  ];

  stylix.targets.fzf.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--ansi"
      "--bind=tab:down,btab:up,change:top,ctrl-space:toggle"
      "--border=rounded"
      "--cycle"
      "--ignore-case"
      "--info=hidden"
      "--layout=reverse"
      "--multi"
      "--tiebreak=begin"
    ];
  };

  stylix.targets.bat.enable = true;
  programs.bat.enable = true;

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
      set -g popup-border-lines none
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
    dotDir = "${config.xdg.dataHome}/zsh";
    plugins = with pkgs; [
      (mkZshPlugin { pkg = zsh-autosuggestions; })
      (mkZshPlugin {
        pkg = zsh-fzf-tab;
        file = "fzf-tab.plugin.zsh";
      })
      (mkZshPlugin { pkg = zsh-syntax-highlighting; })
      (mkZshPlugin {
        pkg = {
          pname = "zsh-simple-abbreviations";
          src = sources.zsh-simple-abbreviations;
        };
        file = "zsh-simple-abbreviations.zsh";
      })
    ];
    autocd = true;
    defaultKeymap = "emacs";
    history = {
      save = 99999;
      size = 99999;
    };
    envExtra = ''
      if [[ "$PROFILE_STARTUP" == true ]]; then
        zmodload zsh/zprof
        PS4=$'%D{%M%S%.} %N:%i> '
        exec 3>&2 2>$HOME/startlog.$$
        setopt xtrace prompt_subst
      fi
    '';
    completionInit = ''
      autoload -U compinit && compinit -C
    '';
    initContent =
    with pkgs;
    with config.lib.stylix.colors;
    ''
      autoload -Uz add-zsh-hook
      autoload -Uz colors
      autoload -Uz down-line-or-beginning-search
      autoload -Uz up-line-or-beginning-search

      setopt histverify

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
      export FZF_DEFAULT_OPTS="${config.home.sessionVariables.FZF_DEFAULT_OPTS}"

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

      if [[ "$USER" != "root" ]] && [[ "$TMUX" == *"tmux"* ]]; then
        zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
      fi

      zstyle ':fzf-tab:*' use-fzf-default-opts yes

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

      if [[ -f "${config.programs.zsh.dotDir}/zsh_history" ]]; then
        HISTFILE="${config.programs.zsh.dotDir}/zsh_history"
      else
        HISTFILE="$HOME/.zsh_history"
      fi

      zsh-simple-abbreviations --set prog "progress -Mc"

      function cat() {
        # check if the last argument is an image
        case "''${@[-1]}" in
          *.gif|*.png|*.jpg|*.jpeg|*.webp)
            kitty +kitten icat "$@"
          ;;
          *)
            bat \
              --theme=base16-stylix \
              --style='changes,snip,numbers' \
              --paging=never \
              --wrap=never \
              "$@"
          ;;
        esac
      }

      function flake() {
        case "$1" in
          init)
            shift
            nix flake init -t flake-parts#templates.default "$@"
          ;;
          *)
            nix flake "$@"
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

      if [[ "$PROFILE_STARTUP" == true ]]; then
        unsetopt xtrace
        exec 2>&3 3>&-; zprof > ~/zshprofile$(date +'%s')
      fi
    '';
    shellAliases = {
      ":q" = "exit";
      "\\$" = "";
      cd = "z";
      cp = "cp -riv";
      gcd = "sudo gc -d";
      ln = "ln -v";
      mkdir = "mkdir -vp";
      mv = "mv -iv";
      nr = "nix repl";
      rm = "rm -v";
      rr = "ranger_cd";
      rsync = "rsync --old-args";
      snapper = "snapper -c persist";
      tb = "termbin";
      termbin = "nc termbin.com 9999";
      tree = "ls --tree";
      x = "exit";
    } // lib.mapAttrs (n: v: pkgs.matchPackageCommand v) {
      df = "pydf";
      ls = "eza -lh --git -s type";
    };
  };

  custom.persistence.files = [
    ".local/share/zsh/zsh_history"
  ];
}
