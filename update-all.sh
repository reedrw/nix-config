#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bat gawk ncurses niv

# This script will update all of the sources.json files generated by niv

shpid="$$"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
white="$(tput setaf 7)"
reset="$(tput sgr 0)"
bold="$(tput bold)"
hide="$(tput civis)"
norm="$(tput cnorm)"
chars="/-\|"
pwd="$PWD"

echo -en "$hide"
find . -type f -name "update-sources.sh" -exec readlink -f {} \; | while read -r updatescript; do
  (
    dir="$(dirname -- "$updatescript")"
    md5="$(md5sum <<<"$dir" | awk '{print $1}')"
    cd "$dir" || exit
    niv show > "/tmp/$md5"
    (
      TEMP="$(mktemp)"
      $updatescript > "$TEMP" &

      relpath="$(realpath --relative-to="$pwd" "$updatescript")"

      while [[ -d /proc/"$!" ]]; do
        for (( i=0; i<${#chars}; i++ )); do
          sleep 0.075
          echo -en "[$green${chars:$i:1}$reset]$white Running $bold$green$relpath$reset..." "\r"
        done
      done

      echo -e "\n$(<"$TEMP")"
      rm "$TEMP"

      fn="$(realpath --relative-to="$pwd" ./nix/sources.json)"
      diff -u --label="a/$fn" "/tmp/$md5" --label="b/$fn" <(niv show) >> "/tmp/$shpid.diff"
      rm "/tmp/$md5"
    )
  )
done

echo -en "$bold$yellow"Updated sources:"$reset\n"
bat --theme=base16 --paging=never -p "/tmp/$shpid.diff"
echo -en "$norm"

if [[ -s "/tmp/$shpid.diff" ]]; then
  while true; do
    read -p "Do you wish to install these updates?" yn
    case $yn in
        [Yy*]* )
          HomeManagerURL="$(jq -r '.["home-manager"].url' ./nix/sources.json)"
          nixpkgsURL="$(jq -r '.["nixpkgs-unstable"].url' ./nix/sources.json)"
          installedHomeManager="$(nix-channel --list | grep "home-manager " | cut -d' ' -f2-)"

          echo "Checking home-manager..."
          if [[ "$installedHomeManager" != "$nixpkgsURL" ]]; then
            echo "Installing home-manager..."
            nix-channel --add "$HomeManagerURL" home-manager
            nix-channel --update
          fi

          sudo -k
          installedNixpkgs="$(sudo nix-channel --list | grep "nixos " | cut -d' ' -f2-)" || exit 1
          echo "Checking nixpkgs..."
          if [[ "$installedNixpkgs" != "$nixpkgsURL" ]]; then
            echo "Updating nixpkgs..."
            sudo nix-channel --add "$nixpkgsURL" nixos
            sudo nix-channel --update
            sudo nixos-rebuild switch --upgrade
          fi

          echo "Building home-manager config..."
          home-manager switch
        break;;
        [Nn]* ) exit
        ;;
    esac
  done
fi
rm "/tmp/$shpid.diff"

