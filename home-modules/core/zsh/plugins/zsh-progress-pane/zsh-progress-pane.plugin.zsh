# ~/.config/zsh/progress-pane.zsh
# Auto-open a tmux pane at the bottom showing `progress -mp PID`
# for any foreground command that runs longer than $PROGRESS_PANE_DELAY.

: ${PROGRESS_PANE_DELAY:=5}     # seconds before the pane appears
: ${PROGRESS_PANE_HEIGHT:=8}    # pane height in lines

# Commands progress knows about by default. Extend via PROGRESS_PANE_EXTRA.
# To see the full list on your system: progress --help
: ${PROGRESS_PANE_COMMANDS:="cp mv dd tar cat tac grep fgrep egrep cut sort \
    md5sum sha1sum sha224sum sha256sum sha384sum sha512sum \
    gzip gunzip pigz bzip2 bunzip2 lbzip2 pbzip2 xz lzma zcat bzcat \
    rsync scp adb mbuffer p7zip 7z"}
: ${PROGRESS_PANE_EXTRA:=""}    # space-separated, user-defined additions

_progress_pane_token=""

_progress_pane_preexec() {
    [[ -z "$TMUX" ]] && return
    command -v progress >/dev/null 2>&1 || return

    local cmd="${1%% *}"
    [[ "$cmd" == "sudo" ]] && cmd="${${1#sudo }%% *}"
    cmd="${cmd##*/}"

    local allowed matched=0
    for allowed in ${=PROGRESS_PANE_COMMANDS} ${=PROGRESS_PANE_EXTRA}; do
        [[ "$cmd" == "$allowed" ]] && { matched=1; break; }
    done
    (( matched )) || return

    local token_dir
    token_dir=$(mktemp -d /tmp/zsh-progress-XXXXXX) || return
    touch "$token_dir/alive"
    _progress_pane_token="$token_dir"

    local shell_pid=$$

    {
        sleep $PROGRESS_PANE_DELAY

        [[ ! -f "$token_dir/alive" ]] && { command rm -rf "$token_dir"; return; }

        local -a target_pids
        local pid
        for pid in ${(f)"$(pgrep -P $shell_pid 2>/dev/null)"}; do
            kill -0 "$pid" 2>/dev/null && target_pids+=("$pid")
        done
        (( ${#target_pids} == 0 )) && { command rm -rf "$token_dir"; return; }

        # Write PIDs so precmd can check for suspension later.
        printf '%s\n' $target_pids > "$token_dir/pids"

        local p_args=()
        for pid in $target_pids; do p_args+=(-p "$pid"); done

        local pane_id
        pane_id=$(tmux split-window -fdv -l $PROGRESS_PANE_HEIGHT \
            -P -F '#{pane_id}' \
            "exec progress -m $p_args" 2>/dev/null) || { command rm -rf "$token_dir"; return; }

        echo "$pane_id" > "$token_dir/pane_id"
        if [[ ! -f "$token_dir/alive" ]]; then
            tmux kill-pane -t "$pane_id" 2>/dev/null
            command rm -rf "$token_dir"
        fi
    } &!
}

_progress_pane_precmd() {
    local token_dir="$_progress_pane_token"
    _progress_pane_token=""
    [[ -z "$token_dir" || ! -d "$token_dir" ]] && return

    # If the pane is open and any tracked PID is still alive, the process was
    # suspended (Ctrl+Z) rather than finished. Keep the pane and re-arm for
    # the next precmd (which will fire when fg'd and the process actually exits).
    if [[ -f "$token_dir/pane_id" && -f "$token_dir/pids" ]]; then
        local pid any_alive=0
        for pid in ${(f)"$(< "$token_dir/pids")"}; do
            if kill -0 "$pid" 2>/dev/null; then
                any_alive=1
                break
            fi
        done
        if (( any_alive )); then
            _progress_pane_token="$token_dir"
            return
        fi
    fi

    command rm -f "$token_dir/alive"

    if [[ -f "$token_dir/pane_id" ]]; then
        tmux kill-pane -t "$(< "$token_dir/pane_id")" 2>/dev/null
    fi

    command rm -rf "$token_dir"
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _progress_pane_preexec
add-zsh-hook precmd  _progress_pane_precmd
