#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq

main(){

  api="https://addons.mozilla.org/api/v4/addons/addon"
  extensions="$(jq -r '.[]' extensions.json)"

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


}

ffz(){

  url="$(curl -s https://www.frankerfacez.com/ | grep firefox | sed -n 's/.*href="\([^"]*\).*/\1/p')"

  sha256="$(nix-prefetch-url "$url")"

  echo  "  (pkgs.fetchFirefoxAddon {"
  echo  "    name = \"FrankerFaceZ\";"
  echo  "    url = \"$url\";"
  echo  "    sha256 = \"$sha256\";"
  echo  "  })"


}

{
  echo "pkgs: ["
  main
  ffz
  echo "]"
} > sources.nix
