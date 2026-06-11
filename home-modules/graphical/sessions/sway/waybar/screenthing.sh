#!/usr/bin/env bash

bar-module(){
  local a
  local arr
  local screenls

  a="$(screen -ls | tail -1 | grep "Socket")"
  # shellcheck disable=SC2206
  arr=($a)
  # shellcheck disable=SC2124
  screenls="${arr[@]:0:2}"

  if [[ "${arr[0]}" != "No" ]]; then
    echo "$screenls"
  else
    echo
  fi
  sleep 3
}

menu(){
  return 0
}

bar-module
