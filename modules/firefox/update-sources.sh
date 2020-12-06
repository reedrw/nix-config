#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq

main(){

  api="https://addons.mozilla.org/api/v4/addons/addon"
  extensions="$(jq -r '.[]' extensions.json)"

  echo "pkgs: ["

  for name in $extensions; do

    url="$(curl -s "$api/$name/" | \
      jq -r '.current_version.files[0].url')"

    sha256="$(nix-prefetch-url "$url")"

    echo  "  (pkgs.fetchFirefoxAddon {"
    echo  "    name = \"$name\";"
    echo  "    url = \"$url\";"
    echo  "    sha256 = \"$sha256\";"
    echo  "  })"

  done

  echo "]"

}

main > sources.nix
