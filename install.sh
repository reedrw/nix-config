#!/usr/bin/env bash

set -e

dir="$(dirname "$(readlink -f "$0")")"
flakePath="${flakePath:-"$dir"}"

nixCommand=(nix --experimental-features 'nix-command flakes' --accept-flake-config)

helpMessage(){
  local green='\033[0;32m'
  local yellow='\033[0;33m'
  local bold='\033[1m'
  local NC='\033[0m' # No Color
  echo -e "Usage: ${bold}$(basename "$0") ${yellow}[--boot|--switch|--build|--help] ${NC}[HOST]"
  echo -e "${green}  --boot         ${NC}Build and add boot entry for the system configuration"
  echo -e "${green}  --build        ${NC}Build the system configuration"
  echo -e "${green}  --help         ${NC}Show this help message"
  echo -e "${green}  --switch       ${NC}Build and switch to the system configuration (default)"
  echo -e "${green}  --verbose      ${NC}Enable verbose output"
}

main(){
  case $1 in
    --boot)
      sudo nixos-rebuild boot --flake "$flakePath/.#$2" -L --option eval-cache false
      ;;
    --build)
      if [ "$#" -lt 2 ]; then
        output="$(hostname)"
      else
        output="$2"
      fi
      if grep -q "@" <<< "$output"; then
        "${nixCommand[@]}" build "$flakePath/.#homeConfigurations.$output.activationPackage" -L --option eval-cache false "${@:3}"
      else
        "${nixCommand[@]}" build "$flakePath/.#nixosConfigurations.$output.config.system.build.toplevel" -L --option eval-cache false "${@:3}"
      fi
      ;;
    --help|-h)
      helpMessage
      ;;
    --list-outputs)
      nix eval --impure --raw --expr "
        let
          flake = builtins.getFlake \"path:$flakePath/.\";
          nixosConfigurations = builtins.attrNames flake.nixosConfigurations;
          homeConfigurations = builtins.attrNames flake.homeConfigurations;
        in
          builtins.concatStringsSep \"\\n\" (nixosConfigurations ++ homeConfigurations) + \"\\n\""
      ;;
    --list-systems)
      nix eval --impure --raw --expr "
        let
          flake = builtins.getFlake \"path:$flakePath/.\";
          nixosConfigurations = builtins.attrNames flake.nixosConfigurations;
        in
          builtins.concatStringsSep \"\\n\" nixosConfigurations + \"\\n\""
      ;;
    --verbose|-v)
      shift;
      set -x
      main "$@"
      ;;
    --switch|*)
      sudo nixos-rebuild switch --flake "$flakePath/.#$2" -L --option eval-cache false "${@:3}"
      [[ "$USER" != "root" ]] && home-manager switch
      ;;
  esac
}
main "$@"
