#!/usr/bin/env bash

# Gets the average battery percentage of all batteries on the system.

if command -v acpi &> /dev/null; then
  charging="$(acpi -a | grep -c "on-line")"
  percentage="$(acpi \
    | grep -v "rate information unavailable" \
    | sed -e 's/%.*$//g' -e 's/^.*, //g' \
    | awk '{ sum += $1; n++ } END { if (n > 0) printf "%d%\n", int(sum / n); }'
  )"
  if [ "$charging" -gt 0 ]; then
    echo "$percentage+"
  else
    echo "$percentage"
  fi
else sleep infinity
fi
sleep 10
