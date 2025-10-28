#!/usr/bin/env bash

export DISPLAY=:0

COPY_CMD="xclip -i -selection clipboard"
PASTE_CMD="xclip -o -selection clipboard"

PREV_CLIP=""

clean() {
    python3 - "$1" <<EOF
import sys
import unalix

url = sys.argv[1]
print(unalix.clear_url(url=url))
EOF
}

while clipnotify; do
  CURR_CLIP=$($PASTE_CMD) || continue
  if [ "$CURR_CLIP" != "$PREV_CLIP" ]; then
    # Check if the clipboard starts with 'http'
    case "$CURR_CLIP" in
      http*)
        echo "Clipboard looks like a URL; cleaning"
        cleaned=$(clean "$CURR_CLIP")
        printf "%s" "$cleaned" | $COPY_CMD # printf because POSIX sh doesn't have -n, and we don't want to add a newline
        ;;
    esac
  fi
  PREV_CLIP="$CURR_CLIP"
done
