#!/usr/bin/env nix-shell
#! nix-shell -i bash -p util-linux gnused libnotify

# This script shows a notification with the current calendar.
# It highlights the current day with a color.
#
# Usage: calnotify.sh [color]
#  color: hex color code (default: 32CD32)
#
#  Example:
#  calnotify.sh 32CD32

# shellcheck shell=bash
green="${1:-32CD32}"

day="$(date +'%-d ' | sed 's/\b[0-9]\b/ &/g')"
cal="$(cal | sed -e 's/^/ /g' -e 's/$/ /g' -e "s/$day/\<span color=\'#$green\'\>\<b\>$day\<\/b\>\<\/span\>/" -e '1d')"
top="$(cal | sed '1!d')"

notify-send "$top" "$cal"
