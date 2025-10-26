#! /usr/bin/env nix-shell
#! nix-shell -i bash -p updog openssl

set -x

passwordFile="$HOME/.cache/updog-password"
if [[ -f "$passwordFile" && -s "$passwordFile" ]]; then
  UPDOG_PASSWORD="$(cat "$passwordFile")"
else
  UPDOG_PASSWORD="$(openssl rand -hex 16)"
  echo "$UPDOG_PASSWORD" > "$passwordFile"
fi

updog \
  --directory ~/files/share \
  --username "user" \
  --password "$UPDOG_PASSWORD"
