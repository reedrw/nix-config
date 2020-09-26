{ config, lib, pkgs, ... }:

let

  sources = import ./nix/sources.nix;

in
{

  programs = {

    command-not-found = {
      enable = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      enableNixDirenvIntegration = true;
    };

    dircolors = {
      enable = true;
    };

    zsh = {
      enable = true;
      plugins = let
        fzf-tab = {
          name = "fzf-tab";
          src = sources.fzf-tab;
        };
        zsh-syntax-highlighting = {
          name = "zsh-syntax-highlighting";
          src = sources.zsh-syntax-highlighting;
        };
      in [
        fzf-tab
        zsh-syntax-highlighting
      ];
      autocd = true;
      defaultKeymap = "emacs";
      initExtra = ''
        while read -r i; do
          autoload -Uz "$i"
        done << EOF
          colors
          compinit
          down-line-or-beginning-search
          up-line-or-beginning-search
        EOF

        while read -r i; do
          setopt "$i"
        done << EOF
          correct
          interactivecomments
          histverify
        EOF

        unsetopt nomatch

        source ${sources.oh-my-zsh}/lib/git.zsh
        source ${sources.oh-my-zsh}/plugins/sudo/sudo.plugin.zsh
        source ${config.lib.base16.base16template "shell"}
        source <(${pkgs.any-nix-shell}/bin/any-nix-shell zsh)

        colors
        setopt promptsubst
        PROMPT='%(!.%B%{$fg[red]%}%n@.%{$fg_bold[green]%}%n@)%m:%{$fg_bold[blue]%} %(!.%d.%~) %{$reset_color%}$(git_prompt_info)%(!.#.$) '
        RPROMPT='%(?..%{$fg[red]%} %? %{$reset_color%})%B %{$reset_color%}%h'

        ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg[yellow]%}git:"
        ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}) "
        ZSH_THEME_GIT_PROMPT_DIRTY=" *"
        ZSH_THEME_GIT_PROMPT_CLEAN=""

        SPROMPT="zsh: correct %F{red}'%R'%f to %F{red}'%r'%f [%B%Uy%u%bes, %B%Un%u%bo, %B%Ue%u%bdit, %B%Ua%u%bbort]? "

        #  Check if current shell is a ranger subshell
        if test "$RANGER_LEVEL" && ! [[ $(ps -o comm= $PPID) == "nvim" ]]; then
          alias ranger="exit"
          export PROMPT="(ranger) $PROMPT"
        fi

        #  nix-shell prompt
        if [[ $IN_NIX_SHELL != "" ]] || [[ $IN_NIX_RUN != "" ]]; then
          output=$(echo $ANY_NIX_SHELL_PKGS | xargs)
            if [[ -n $name ]] && [[ $name != shell ]]; then
              output+=" "$name
            fi
          if [[ -n $output ]]; then
            output=$(echo $output $additional_pkgs | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
          else
            printf "[unknown environment]"
          fi
          PROMPT="%{$fg_bold[green]%}nix-shell:%{$reset_color%} [ %{$fg[yellow]%}$output%{$reset_color%} ] %{$fg[blue]%}%(!.%d.%~) %{$reset_color%}%(!.#.$) "
        fi

        compinit

        local extract="
        # trim input
        local in=\''${\''${\"\$(<{f})\"%\$'\0'*}#*\$'\0'}
        # get ctxt for current completion
        local -A ctxt=(\"\''${(@ps:\2:)CTXT}\")
        # real path
        local realpath=\''${ctxt[IPREFIX]}\''${ctxt[hpre]}\$in
        realpath=\''${(Qe)~realpath}
        "

        FZF_TAB_COMMAND=(
          ${pkgs.fzf}/bin/fzf
          --ansi   # Enable ANSI color support, necessary for showing groups
          --expect='$continuous_trigger,$print_query' # For continuous completion
          --color=16
          --nth=2,3 --delimiter='\x00'  # Don't search prefix
          --layout=reverse --height=''\'''${FZF_TMUX_HEIGHT:=75%}'
          --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
          '--query=$query'   # $query will be expanded to query string at runtime.
          '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
          --print-query
        )
        zstyle ':fzf-tab:*' command $FZF_TAB_COMMAND

        zstyle ':fzf-tab:*' extraopts '--no-sort'
        zstyle ':completion:*' sort false
        zstyle ':fzf-tab:*' insert-space true
        zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm,cmd -w -w"
        zstyle ':fzf-tab:complete:cd:*' extra-opts --preview=$extract'${pkgs.exa}/bin/exa -1 --color=always $realpath'
        zstyle ':fzf-tab:complete:(vi|vim|nvim):*' extra-opts --preview=$extract'[ -d $realpath ] && ${pkgs.exa}/bin/exa -1 --color=always $realpath || ${pkgs.bat}/bin/bat -p --theme=base16 --color=always $realpath'
        zstyle ':fzf-tab:complete:kill:argument-rest' extra-opts --preview=$extract'ps --pid=$in[(w)1] -o cmd --no-headers -w -w' --preview-window=down:3:wrap


        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
        zstyle ':completion:*' menu select
        zstyle ':completion:*' special-dirs true
        zmodload zsh/complist

        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search

        unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
        unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND

        bindkey '^[[A'  up-line-or-beginning-search
        bindkey '^[[B'  down-line-or-beginning-search
        bindkey '^[[7~' beginning-of-line
        bindkey '^[[8~' end-of-line

        git(){
          case "$1" in
            clone)
              command git clone --recurse-submodules "''${@:2}"
            ;;
            *)
              command git "$@"
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

      '';
      shellAliases = {
        ":q" = "exit";
        b    = "${pkgs.bat}/bin/bat --theme=base16";
        cat  = "b --plain --paging=never";
        cp   = "cp -v";
        df   = "${pkgs.pydf}/bin/pydf";
        ln   = "ln -v";
        ls   = "${pkgs.exa}/bin/exa -lh --git";
        mv   = "mv -v";
        ping = "${pkgs.prettyping}/bin/prettyping --nolegend";
        rm   = "rm -v";
        tree = "ls --tree";
        wget = "${pkgs.wget}/bin/wget --progress=dot:giga";
        x    = "exit";
      };
    };
  };
}

