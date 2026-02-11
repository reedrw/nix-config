#! /usr/bin/env bash

function main(){
  local rar
  local mountpoint
  local iso

  rar="$1"
  mountpoint="${2:-./iso}"

  iso="$(basename -- "$rar" ".rar").iso"

  if [[ "$1" == "-l" ]]; then
    iso="$(losetup -n -O BACK-FILE "$(findmnt -n -o SOURCE "$mountpoint")")"
    mountiso -l "$mountpoint"
    rm --interactive "$iso"
    return 0
  fi

  sudo sh -c "rar x '$rar' && mountiso '$iso'"
}

main "$@"
