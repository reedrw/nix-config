#!/usr/bin/env bash

acpi | sed -e 's/%.*$//g' -e 's/^.*, //g' | awk '{ sum += $1; n++ } END { if (n > 0) printf "%d%\n", int(sum / n); }'
sleep 3;
