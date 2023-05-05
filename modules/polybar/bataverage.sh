#!/usr/bin/env bash

if [[ "$(hostname)" != *"desktop"* ]]; then
  acpi | sed -e 's/%.*$//g' -e 's/^.*, //g' | awk '{ sum += $1; n++ } END { if (n > 0) printf "%d%\n", int(sum / n); }'
else sleep infinity
fi
sleep 10
