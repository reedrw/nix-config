{ config, osConfig, lib, pkgs, util, ... }:
let
  sources = (util.importFlake ./plugins).inputs or {};

  # Pre-bake the generated integration scripts instead of forking the
  # binaries (`eval "$(...)"`) on every shell start. Saves ~6ms per prompt.
  fzfZshInit = pkgs.runCommand "fzf-zsh-init" { } ''
    ${pkgs.fzf}/bin/fzf --zsh > $out
  '';
  zoxideZshInit = pkgs.runCommand "zoxide-zsh-init" { } ''
    ${pkgs.zoxide}/bin/zoxide init zsh > $out
  '';

  # romkatv's instant-zsh trick: print a lookalike prompt before anything else
  # loads, then swap in the real one. Zcompiled (source prefers the .zwc).
  instantZshInit = pkgs.runCommand "instant-zsh-init" { } ''
    cp ${
      pkgs.fetchurl {
        url = "https://gist.githubusercontent.com/romkatv/8b318a610dc302bdbe1487bb1847ad99/raw/3f69117c0d456aa6c8410d553c4799252642a1b4/instant-zsh.zsh";
        hash = "sha256-YdejPAYKIh0hL+fbxBdMsPxynVUDnVeydQzXXvXMbKM=";
      }
    } $out
    ${pkgs.zsh}/bin/zsh -c "zcompile $out"
  '';
in
{
  imports = [
    ./direnv.nix
    ./zoxide.nix
  ];

  stylix.targets.bat.enable = true;

  # We set ZDOTDIR at system level, so we don't need
  # to bootstrap the the zsh environment like this.
  home.file.".zshenv".enable = false;

  programs = {
    fzf = {
      enable = true;
      # integration is sourced from a pre-baked script instead (see initContent)
      enableZshIntegration = false;
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
        "--color=bg:-1,bg+:19,fg:7,fg+:15,header:4,hl:4,hl+:4,info:3,marker:6,pointer:6,prompt:3,spinner:6"
      ];
    };

    bat.enable = true;

    tmux = {
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
        set -s extended-keys on
        set -g extended-keys-format csi-u
        set -as terminal-features 'xterm*:extkeys'
        set -as terminal-features '*:hyperlinks'
        set -g popup-border-lines none
        set -g popup-style 'bg=default'
        bind-key -T copy-mode / command-prompt -T search -p "(search down)" { send-keys -X search-forward -- "%%" }
        bind-key -T copy-mode ? command-prompt -T search -p "(search up)" { send-keys -X search-backward -- "%%" }
      '';
    };

    zsh = let
      mkZshPlugin = { pkg, file ? "${pkg.pname}.plugin.zsh" }: {
        name = pkg.pname;
        inherit (pkg) src;
        inherit file;
      };
    in
    {
      enable = true;
      dotDir = "${config.xdg.dataHome}/zsh";
      plugins = with pkgs; map lib.fix [
        (_: mkZshPlugin { pkg = zsh-autosuggestions; })
        (_: mkZshPlugin {
          pkg = zsh-fzf-tab;
          file = "fzf-tab.plugin.zsh";
        })
        (_: mkZshPlugin { pkg = zsh-syntax-highlighting; })
        (self: {
          name = "zsh-simple-abbreviations";
          src = sources.${self.name};
          file = "zsh-simple-abbreviations.zsh";
        })
        (self: {
          name = "zsh-progress-pane";
          src = ./plugins + "/${self.name}";
          file = "${self.name}.plugin.zsh";
        })
      ];
      autocd = true;
      defaultKeymap = "emacs";
      history = {
        save = 99999;
        size = 99999;
      };
      completionInit = ''
        autoload -Uz compinit
        # Keep a zcompiled dump next to .zcompdump; compinit's `source` prefers
        # the .zwc, which loads ~4ms faster. Regenerate when the dump changes.
        if [[ ! -s $ZDOTDIR/.zcompdump.zwc || $ZDOTDIR/.zcompdump -nt $ZDOTDIR/.zcompdump.zwc ]]; then
          compinit -C && zcompile $ZDOTDIR/.zcompdump
        else
          compinit -C
        fi
      '';
      envExtra = ''
        if [[ "$PROFILE_STARTUP" == true ]]; then
          zmodload zsh/zprof
          PS4=$'%D{%M%S%.} %N:%i> '
          exec 3>&2 2>$HOME/startlog.$$
          setopt xtrace prompt_subst
        fi
      '';
      initContent = lib.mkMerge [
        # Instant prompt: print a static lookalike prompt before anything else
        # loads so startup feels instant. Must run before everything else.
        (lib.mkOrder 500
        ''
          source ${instantZshInit}
          if [[ -t 1 ]]; then
            typeset -g _instant_loading_prompt
            if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" || -n "$DISTROBOX_ENTER_PATH" ]]; then
              _instant_loading_prompt='%(!.%F{red}.%F{green})%n%f@%F{magenta}%M %B%F{blue}%(!.%d.%~)%f%b  %(!.#.$) '
            else
              _instant_loading_prompt='%(!.%F{red}.%F{green})%n%f %B%F{blue}%(!.%d.%~)%f%b  %(!.#.$) '
            fi
            instant-zsh-pre "$_instant_loading_prompt"
          fi
        '')
        (with pkgs;
        ''
        autoload -Uz add-zsh-hook
        autoload -Uz down-line-or-beginning-search
        autoload -Uz up-line-or-beginning-search

        setopt histverify

        unsetopt nomatch

        # fzf/zoxide integrations sourced from pre-baked scripts (no fork at startup)
        if [[ $options[zle] = on ]]; then
          source ${fzfZshInit}
        fi
        source ${zoxideZshInit}

        source ${oh-my-zsh.src}/lib/async_prompt.zsh
        source ${oh-my-zsh.src}/lib/git.zsh
        source ${oh-my-zsh.src}/plugins/sudo/sudo.plugin.zsh
        source ${ranger.src}/examples/shell_automatic_cd.sh 2> /dev/null

        export NIX_PATH=$XDG_STATE_HOME/nix/defexpr/channels:/nix/var/nix/profiles/per-user/root/channels''${NIX_PATH:+:$NIX_PATH}

        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi

        setopt promptsubst
        PROMPT='%B%F{blue}%(!.%d.%~)%f%b $(git_prompt_info) %(?..%K{19}%F{red}!%?%k%f )%(!.#.$) '

        # show hostname if in ssh session
        if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$DISTROBOX_ENTER_PATH" ]; then
          PROMPT="%(!.%F{red}.%F{green})%n%f@%F{magenta}%M $PROMPT"
        else
          PROMPT="%(!.%F{red}.%F{green})%n%f $PROMPT"
        fi

        PROMPT_ORIG=$PROMPT

        ZSH_THEME_GIT_PROMPT_PREFIX="(%F{yellow}git:"
        ZSH_THEME_GIT_PROMPT_SUFFIX="%f)"
        ZSH_THEME_GIT_PROMPT_DIRTY=" *"
        ZSH_THEME_GIT_PROMPT_CLEAN=""

        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
        ZSH_AUTOSUGGEST_STRATEGY="completion"
        ZSH_AUTOSUGGEST_USE_ASYNC="yes"

        export MANPAGER="nvim +Man\!"
        export EDITOR="${config.home.sessionVariables.EDITOR}"
        export FZF_DEFAULT_OPTS="${config.home.sessionVariables.FZF_DEFAULT_OPTS}"

        # Make sure nix-shell gets its completions loaded
        # BUG: Doesn't unload completions when leaving direnv
        function set-completions-from-path() {
          [[ -n "$ANY_NIX_SHELL_PKGS" ]] || return
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
        precmd_functions+=(set-completions-from-path)
        chpwd_functions+=(set-completions-from-path)

        # Draw a horizontal line between commands
        first_command_sent=0
        line_not_drawn=1
        force_draw=0
        function draw-separator-line() {
          if [[ $first_command_sent -eq 1 || force_draw -eq 1 ]] && [[ $line_not_drawn -eq 1 ]]; then
            if [[ "$TERM" != "linux" ]]; then
              PROMPT=$'%{%F{8}%}%{\e(0%}''${(r:$COLUMNS::q:)}%{\e(B%}'$PROMPT
            fi
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

        precmd_functions+=(draw-separator-line)

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

        if [[ -f "${osConfig.custom.persistDir}/${config.xdg.dataHome}/zsh/zsh_history" ]]; then
          HISTFILE="${osConfig.custom.persistDir}/${config.xdg.dataHome}/zsh/zsh_history"
        else
          HISTFILE="$HOME/.zsh_history"
        fi
        [[ -d ''${HISTFILE:h} ]] || mkdir -p "''${HISTFILE:h}"

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
      '')
        # Move the _clear-loading-prompt precmd hook to the very end, after every
        # other module's hooks, so the loading prompt isn't erased too soon.
        (lib.mkOrder 1600
        ''
          instant-zsh-post
        '')
      ];
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
      } // lib.mapAttrs (_: v: pkgs.matchPackageCommand v) {
        df = "pydf";
        ls = "eza -lh --git -s type";
      };
    };
  };

  custom.persistence.files = [
    ".local/share/zsh/zsh_history"
  ];
}
