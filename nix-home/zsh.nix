{ config, lib, pkgs, ... }:

let

  sources = import ./nix/sources.nix;

  fzf-tab = {
    name = "fzf-tab";
    src = builtins.fetchTarball {
      url = sources.fzf-tab.url;
      sha256 = sources.fzf-tab.sha256;
    };
  };

  zsh-syntax-highlighting = {
    name = "zsh-syntax-highlighting";
    src = builtins.fetchTarball {
      url = sources.zsh-syntax-highlighting.url;
      sha256 = sources.zsh-syntax-highlighting.sha256;
    };
  };

  oh-my-zsh = pkgs.fetchFromGitHub {
    owner = sources.oh-my-zsh.owner;
    repo = sources.oh-my-zsh.repo;
    rev = sources.oh-my-zsh.rev;
    sha256 = sources.oh-my-zsh.sha256;
  };

in
{

  services.lorri.enable = true;

  programs = {

    command-not-found = {
      enable = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
    };

    dircolors = {
      enable = true;
    };

    zsh = {
      enable = true;
      plugins = [
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

        source "${oh-my-zsh}/lib/git.zsh"
        source "${oh-my-zsh}/plugins/sudo/sudo.plugin.zsh"
        eval "$(${pkgs.any-nix-shell}/bin/any-nix-shell zsh)"

        colors
        setopt promptsubst
        PROMPT='%(!.%B%{$fg[red]%}%n%{$reset_color%}@.%{$fg[green]%}%n%{$reset_color%}@)%m:%{$fg_bold[blue]%} %(!.%d.%~) %{$reset_color%}$(git_prompt_info)%(!.#.$) '
        RPROMPT='%(?..%{$fg[red]%} %? %{$reset_color%})%B %{$reset_color%}%h'

        ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg[yellow]%}git:"
        ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}) "
        ZSH_THEME_GIT_PROMPT_DIRTY=" *"
        ZSH_THEME_GIT_PROMPT_CLEAN=""

        SPROMPT="zsh: correct %F{red}'%R'%f to %F{red}'%r'%f [%B%Uy%u%bes, %B%Un%u%bo, %B%Ue%u%bdit, %B%Ua%u%bbort]? "

        #  Check if current shell is a ranger subshell
        if test "$RANGER_LEVEL" && ! [[ $(ps -o comm= $PPID) == "nvim" ]]; then
          alias ranger="exit"
          export PROMPT="%{$fg[red]%}RANGER %{$reset_color%} $PROMPT"
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
          export PROMPT="%{$fg_bold[green]%}nix-shell:%{$reset_color%} [ %{$fg[yellow]%}$output%{$reset_color%} ]: %{$fg[blue]%}%(!.%d.%~) %{$reset_color%}%(!.#.$) "
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
          --expect='$continuous_trigger' # For continuous completion
          --color=16
          --nth=2,3 --delimiter='\x00'  # Don't search prefix
          --layout=reverse --height=''\'''${FZF_TMUX_HEIGHT:=75%}'
          --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
          '--query=$query'   # $query will be expanded to query string at runtime.
          '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
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

        source ${config.lib.base16.base16template "shell"}

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

      '';
      shellAliases = {
        ":q" = "exit";
        b    = "${pkgs.bat}/bin/bat --theme=base16 --paging=never";
        cat  = "b --plain";
        cp   = "cp -v";
        df   = "${pkgs.pydf}/bin/pydf";
        ln   = "ln -v";
        ls   = "${pkgs.exa}/bin/exa -lh --git";
        mv   = "mv -v";
        ping = "${pkgs.prettyping}/bin/prettyping --nolegend";
        rm   = "rm -v";
        tree = "ls --tree";
        x    = "exit";
      };
    };
  };
}

