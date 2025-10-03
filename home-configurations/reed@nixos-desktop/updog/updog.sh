#! /usr/bin/env nix-shell
#! nix-shell -i bash -p updog openssl

UPDOG_PASSWORD="$(openssl rand -hex 16)"

echo "$UPDOG_PASSWORD" > /tmp/updog-password

updog \
  --directory ~/files/share \
  --username "user" \
  --password "$UPDOG_PASSWORD"
