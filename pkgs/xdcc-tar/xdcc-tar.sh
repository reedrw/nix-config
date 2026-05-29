#!/usr/bin/env nix-shell
#! nix-shell -i bash -p xdcc-dl gnutar ncurses gawk

if [[ $# -eq 0 ]]; then
  echo 'Usage: xdcc-tar "/msg <bot> XDCC SEND #<pack>"' >&2
  exit 1
fi

input="$*"

if [[ "$input" =~ /msg[[:space:]]+([^[:space:]]+)[[:space:]]+[Xx][Dd][Cc][Cc][[:space:]]+[Ss][Ee][Nn][Dd][[:space:]]+#([0-9]+) ]]; then
  bot="${BASH_REMATCH[1]}"
  pack="${BASH_REMATCH[2]}"
else
  echo "error: could not parse XDCC command — expected /msg <bot> XDCC SEND #<pack>" >&2
  exit 1
fi

# .tar suffix is load-bearing: XDCCPack.set_filename auto-appends the
# bot-provided extension if the --out path doesn't already end in it.
fifo=$(mktemp -u --suffix=.tar)
mkfifo "$fifo"

# Tagged FIFO: both subprocess outputs are funneled here, then one coordinator
# owns all terminal writes. Without this, tar and the status writer race on
# cursor save/restore and tar's output drifts into the status row.
out=$(mktemp -u)
mkfifo "$out"

status_dir=$(mktemp -d)

lines=$(tput lines)
cols=$(tput cols)

# shellcheck disable=SC2329  # invoked indirectly by trap
cleanup() {
  printf '\e[r'                          # reset scrolling region
  printf '\e[%d;1H\n' "$lines"           # cursor to bottom + newline
  rm -rf "$fifo" "$out" "$status_dir"
}
trap cleanup EXIT

printf '\e[2J\e[H'                       # clear screen, cursor home
printf '\e[1;%dr' "$((lines - 1))"       # scroll region: rows 1..lines-1

# tar's verbose output → tagged "T:", line by line
{ tar xvBf "$fifo" 2>&1; echo "$?" > "$status_dir/tar"; } | \
  awk '{print "T:" $0; fflush()}' > "$out" &

# xdcc-dl's progress → tagged "X:", split on \r. Unblock tar on exit in case
# xdcc-dl failed before opening the FIFO.
{ PYTHONUNBUFFERED=1 xdcc-dl --quiet --out "$fifo" "/msg $bot XDCC SEND #$pack" 2>/dev/null
  echo "$?" > "$status_dir/xdcc"
  : <>"$fifo" 2>/dev/null || true
} | awk 'BEGIN{RS="\r|\n"} NF{print "X:" $0; fflush()}' > "$out" &

# Sole terminal writer: read tagged stream, route to scroll region or status row.
while IFS= read -r line; do
  case "$line" in
    T:*) printf '%s\n' "${line#T:}" ;;
    X:*)
      msg=${line#X:}
      msg=${msg:0:$cols}
      printf '\e7\e[%d;1H\e[2K%s\e8' "$lines" "$msg"
      ;;
  esac
done < "$out"

wait

dl_status=$(cat "$status_dir/xdcc" 2>/dev/null || echo 1)
tar_status=$(cat "$status_dir/tar" 2>/dev/null || echo 1)

if [[ $dl_status -ne 0 ]]; then
  exit "$dl_status"
fi
exit "$tar_status"
