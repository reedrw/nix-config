#!/usr/bin/env bash

set -e

dir="$(dirname "$(readlink -f "$0")")"
flakePath="${flakePath:-"$dir"}"
flake="git+file://$flakePath?ref=main"

nixCommand=(nix --experimental-features 'pipe-operator nix-command flakes' --accept-flake-config)
logFormat=(--log-format bar-with-logs)

# if SUDO_ASKPASS is set, use sudo -A
if [ -n "$SUDO_ASKPASS" ]; then
  sudo() {
    SUDO_ASKPASS="$SUDO_ASKPASS" command sudo -A "$@"
  }
fi

# if user is root, sudo should do nothing
if [ "$(id -u)" -eq 0 ]; then
  sudo() {
    "$@"
  }
fi

helpMessage(){
  local green='\033[0;32m'
  local yellow='\033[0;33m'
  local bold='\033[1m'
  local NC='\033[0m' # No Color
  echo -e "Usage: ${bold}$(basename "$0") ${yellow}[--boot|--switch|--build|--build-vm|--help] ${NC}[HOST]"
  echo -e "${green}  --boot         ${NC}Build and add boot entry for the system configuration"
  echo -e "${green}  --build        ${NC}Build the system configuration"
  echo -e "${green}  --help         ${NC}Show this help message"
  echo -e "${green}  --switch       ${NC}Build and switch to the system configuration (default)"
  echo -e "${green}  --verbose      ${NC}Enable verbose output"
}

main(){
  case $1 in
    --boot)
      sudo nixos-rebuild boot --fast --flake "$flake#$2" --accept-flake-config "${logFormat[@]}" "${@:3}"
      ;;
    --build)
      if [ "$#" -lt 2 ]; then
        output="$(hostname)"
      else
        output="$2"
      fi
      if grep -q "@" <<< "$output"; then
        "${nixCommand[@]}" build "${logFormat[@]}" "$flake#homeConfigurations.$output.activationPackage" "${@:3}"
      elif grep -q "nixos-vm" <<< "$output"; then
        "${nixCommand[@]}" build "${logFormat[@]}" "$flake#nixosConfigurations.$output.config.system.build.vm" "${@:3}"
      else
        "${nixCommand[@]}" build "${logFormat[@]}" "$flake#nixosConfigurations.$output.config.system.build.toplevel" "${@:3}"
      fi
      ;;
    --help|-h)
      helpMessage
      ;;
    --list-outputs)
      nix eval --impure --raw --expr "
        let
          flake = builtins.getFlake \"$flake\";
          nixosConfigurations = builtins.attrNames flake.nixosConfigurations;
          homeConfigurations = builtins.attrNames flake.homeConfigurations;
        in
          builtins.concatStringsSep \"\\n\" (nixosConfigurations ++ homeConfigurations) + \"\\n\""
      ;;
    --list-systems)
      nix eval --impure --raw --expr "
        let
          flake = builtins.getFlake \"$flake\";
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
      sudo nixos-rebuild switch --fast --flake "$flake#$2" --accept-flake-config "${logFormat[@]}" "${@:3}"
      ;;
  esac
}
main "$@"
