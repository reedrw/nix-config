#!/usr/bin/env nix-shell
#! nix-shell -i bash -p solaar

# Configure Logitech MX Master 3S SmartShift.
# Run once at login; solaar-cli settings persist on the device.

if command -v solaar-cli &> /dev/null; then
  solaar-cli config "MX Master 3S" smart-shift 18 || true
fi
