#! /usr/bin/env nix-shell
#! nix-shell -i bash -p updog openssl

UPDOG_PASSWORD="$(openssl rand -hex 16)"

echo "$UPDOG_PASSWORD" > /tmp/updog-password

updog -d ~/files/share --password "$UPDOG_PASSWORD"
