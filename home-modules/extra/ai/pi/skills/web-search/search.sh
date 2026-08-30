#! /usr/bin/env nix-shell
#! nix-shell -i bash -p ddgr
# shellcheck shell=bash
# DuckDuckGo search for pi agents. Emits JSON: [{title,url,abstract}, ...]
# Usage: web-search [ddgr-flags...] "query words"
# Defaults to 5 results, no interactive prompt, machine-readable output.
exec ddgr --json --np -C -n "${WEB_SEARCH_RESULTS:-5}" "$@"
