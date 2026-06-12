#! /usr/bin/env bash

# This script is used to fix the pixel format of the droidcam video device
# to fix this issue:

# Fatal: droidcam video device reported pixel format 34524742 (BGR4), expected 32315559 (YU12/I420)
# Try 'v4l2loopback-ctl set-caps "video/x-raw, format=I420, width=640, height=480" /dev/video<N>'
# Error: Unable to query v4l2 device for correct parameters

set -x

# make sure the v4l2loopback-ctl is installed
if ! command -v v4l2loopback-ctl; then
  echo "v4l2loopback-ctl could not be found"
  exit 0
fi

#v4l2loopback-ctl set-caps /dev/video0 "YU12:640x480"
for i in /sys/devices/virtual/video4linux/*; do
  name="$(basename "$i")"
  v4l2loopback-ctl set-caps "/dev/$name" "YU12:640x480";
done
