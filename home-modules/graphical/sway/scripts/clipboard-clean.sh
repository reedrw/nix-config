#!/usr/bin/env bash
# Called by: wl-paste --watch clipboard-clean
# Clipboard content arrives on stdin.

CURR_CLIP="$(cat)"

case "$CURR_CLIP" in
  http*)
    cleaned="$(python3 -c "
import sys, unalix
print(unalix.clear_url(url=sys.argv[1]))
" "$CURR_CLIP")"
    [ "$cleaned" != "$CURR_CLIP" ] && printf "%s" "$cleaned" | wl-copy
    ;;
esac
