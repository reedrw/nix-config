#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bat gawk ncurses niv

# This script will update all of the sources.json files generated by niv

shpid="$$"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
white="$(tput setaf 7)"
bold="$(tput bold)"
reset="$(tput sgr 0)"
hide="$(tput civis)"
norm="$(tput cnorm)"
chars="/-\|"
pwd=$PWD

echo -en "$hide"

find . -type f -name "update-sources.sh" -exec readlink -f {} \; | while read -r updatescript; do
  (
    dir="$(dirname -- "$updatescript")"
    cd "$dir" || exit
    niv show > "/tmp/$(md5sum <<<"$dir" | awk '{print $1}')"
    (

      TEMP=$(mktemp)
      $updatescript > "$TEMP" &

      while [[ -d /proc/$! ]]; do
        for (( i=0; i<${#chars}; i++ )); do
          sleep 0.075
          echo -en "[$green${chars:$i:1}$reset]$white Running $bold$green$(realpath --relative-to="$pwd" "$updatescript")$reset..." "\r"
        done
      done

      echo -e "\n\n$(<"$TEMP")\n"
      rm "$TEMP"
    )
  )
done


find . -type f -name "update-sources.sh" -exec readlink -f {} \; | while read -r updatescript; do
  dir="$(dirname -- "$updatescript")"
  cd "$dir" || exit
  fn="$(readlink -f ./nix/sources.json)"
  diff -u --label="$fn" "/tmp/$(md5sum <<<"$dir" | awk '{print $1}')" --label="$fn" <(niv show) >> "/tmp/$shpid.diff"
  rm "/tmp/$(md5sum <<<"$dir" | awk '{print $1}')"
done

echo -en ""$bold$yellow"Updated Sources:$reset\n"
bat --theme=base16 --paging=never -p "/tmp/$shpid.diff"
rm "/tmp/$shpid.diff"

echo -en "$norm"

