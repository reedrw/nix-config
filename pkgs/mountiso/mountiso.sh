#! /usr/bin/env bash

function unmount(){
  local mountpoint
  mountpoint="$1"

  if mountpoint "$mountpoint" > /dev/null; then
    sudo umount -l "$mountpoint"
    rmdir --ignore-fail-on-non-empty "$mountpoint"
    exit 0
  else
    echo "Path $mountpoint does not exist or is not a mountpoint."
    exit 1
  fi
}

function main(){
  local iso
  local mountpoint

  iso="$1"
  mountpoint="${2:-./iso}"

  if [[ "$1" == "-l" ]]; then
    unmount "$mountpoint"
  fi

  mkdir -p "$mountpoint"
  sudo mount -o loop "$iso" "$mountpoint" \
    || rmdir --ignore-fail-on-non-empty "$mountpoint"
}

main "$@"
