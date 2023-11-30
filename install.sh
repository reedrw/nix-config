#!/usr/bin/env bash

set -e

dir="$(dirname "$0")"

nixCommand=(nix --experimental-features 'nix-command flakes')

helpMessage(){
  local green='\033[0;32m'
  local yellow='\033[0;33m'
  local bold='\033[1m'
  local NC='\033[0m' # No Color
  echo -e "Usage: ${bold}$(basename "$0") ${yellow}[--boot|--switch|--build|--help] ${NC}[HOST]"
  echo -e "${green}  --switch       ${NC}Build and switch to the system configuration (default)"
  echo -e "${green}  --boot         ${NC}Build and add boot entry for the system configuration"
  echo -e "${green}  --build        ${NC}Build the system configuration"
  echo -e "${green}  --help         ${NC}Show this help message"
}

main(){
  case $1 in
    --boot)
      sudo nixos-rebuild boot --flake "$dir/.#$2" -L --option eval-cache false
      ;;
    --build)
      if [ "$#" -lt 2 ]; then
        output="$(hostname)"
      else
        output="$2"
      fi
      if grep -q "@" <<< "$output"; then
        "${nixCommand[@]}" build "$dir/.#homeConfigurations.$output.activationPackage" -L --option eval-cache false "${@:3}"
      else
        "${nixCommand[@]}" build "$dir/.#nixosConfigurations.$output.config.system.build.toplevel" -L --option eval-cache false "${@:3}"
      fi
      ;;
    --help|-h)
      helpMessage
      ;;
    --verbose|-v)
      shift;
      set -x
      main "$@"
      ;;
    --switch|*)
      sudo nixos-rebuild switch --flake "$dir/.#$2" -L --option eval-cache false
      [[ "$USER" != "root" ]] && home-manager switch -L
      ;;
  esac
}
main "$@"
