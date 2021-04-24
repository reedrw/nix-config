{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix;

  fzf-tab-new = pkgs.stdenv.mkDerivation {
    name = "fzf-tab";
    src = sources.fzf-tab;

    installPhase = ''
      mkdir -p $out
      cp -r ./ $out
      substituteInPlace $out/lib/ftb-tmux-popup \
        --replace tmux ${pkgs.tmux}/bin/tmux \
        --replace ' fzf ' ' ${pkgs.fzf}/bin/fzf ' \
        --replace '$commands[fzf]' '${pkgs.fzf}/bin/fzf'
    '';
  };

in
{

  programs = {

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
      plugins =
        let
          fzf-tab = {
            name = "fzf-tab";
            src = fzf-tab-new;
          };
          zsh-syntax-highlighting = {
            name = "zsh-syntax-highlighting";
            src = sources.zsh-syntax-highlighting;
          };
          zsh-autosuggestions = {
            name = "zsh-autosuggestions";
            src = sources.zsh-autosuggestions;
          };
        in
        [
          fzf-tab
          zsh-autosuggestions
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
          interactivecomments
          histverify
        EOF

        unsetopt nomatch

        source ${pkgs.oh-my-zsh.src}/lib/git.zsh
        source ${pkgs.oh-my-zsh.src}/plugins/sudo/sudo.plugin.zsh
        source ${config.lib.base16.base16template "shell"}
        source <(${pkgs.any-nix-shell}/bin/any-nix-shell zsh)
        source ${pkgs.ranger.src}/examples/shell_automatic_cd.sh 2> /dev/null

        colors
        setopt promptsubst
        PROMPT='%(!.%B%{$fg[red]%}%n@.%{$fg_bold[green]%}%n@)%m:%{$fg_bold[blue]%} %(!.%d.%~) %{$reset_color%}$(git_prompt_info)%(!.#.$) '
        RPROMPT='%(?..%{$fg[red]%} %? %{$reset_color%})%B %{$reset_color%}%h'

        ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg[yellow]%}git:"
        ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}) "
        ZSH_THEME_GIT_PROMPT_DIRTY=" *"
        ZSH_THEME_GIT_PROMPT_CLEAN=""

        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#${config.lib.base16.theme.base02}"
        ZSH_AUTOSUGGEST_STRATEGY="completion"
        ZSH_AUTOSUGGEST_USE_ASYNC="yes"

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
          PROMPT="%(!.%{$fg_bold[red]%}.%{$fg_bold[green]%})nix-shell:%{$reset_color%} [ %{$fg[yellow]%}$output%{$reset_color%} ] %{$fg[blue]%}%(!.%d.%~) %{$reset_color%}%(!.#.$) "
        fi

        compinit

        FZF_TAB_FLAGS=(
          -i
          --ansi   # Enable ANSI color support, necessary for showing groups
          --color=16
          --layout=reverse
          --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
          --print-query
        )
        zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
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

        bindkey '^[[A'  up-line-or-beginning-search
        bindkey '^[[B'  down-line-or-beginning-search
        bindkey '^[[1~' beginning-of-line
        bindkey '^[[4~' end-of-line

        command_not_found_handler(){
          if [ -f "$HOME/.cache/nix-index/files" ]; then
            database="$HOME/.cache/nix-index"
          else
            >&2 echo 'No database.'
            return 1
          fi

          argv0=$1; shift
          attr="$(${pkgs.nix-index}/bin/nix-locate --db "$database" --top-level --minimal --at-root --whole-name "/bin/$argv0")"

          if [[ -z $attr ]]; then
            >&2 echo "$argv0: command not found"
            return 127
          fi

          attr="$(echo "$attr" | ${pkgs.fzy}/bin/fzy)" || return 130

          nix run "nixpkgs.$attr" -c "$argv0" "$@"
        }

        c(){
          [[ -p /dev/stdin ]] && \
            ${pkgs.xclip}/bin/xclip -i -selection clipboard || \
            ${pkgs.xclip}/bin/xclip -o -selection clipboard
        }

        git(){
          case "$1" in
            ~)
              cd "$(command git rev-parse --show-toplevel)"
            ;;
            clone)
              ${pkgs.gitAndTools.hub}/bin/hub clone --recurse-submodules "''${@:2}"
            ;;
            *)
              ${pkgs.gitAndTools.hub}/bin/hub "$@"
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
        b = "${pkgs.bat}/bin/bat --theme=base16";
        cat = "b --plain --paging=never";
        cp = "cp -riv";
        df = "${pkgs.pydf}/bin/pydf";
        ln = "ln -v";
        ls = "${pkgs.exa}/bin/exa -lh --git";
        mkdir = "mkdir -vp";
        mv = "mv -iv";
        ping = "${pkgs.prettyping}/bin/prettyping --nolegend";
        ranger = "ranger_cd";
        rm = "rm -v";
        tree = "ls --tree";
        wget = "${pkgs.wget}/bin/wget --progress=dot:giga";
        x = "exit";
      };
    };
  };
}
