{ writeShellScriptBin, writeShellScript }:

let
  blue = ''"$(tput setaf 4)"'';
  green = ''"$(tput setaf 2)"'';
  reset = ''"$(tput sgr0)"'';
  dots = "${blue}....................................................................${reset}";

  echoAndRun = writeShellScript "echoAndRun" ''
    echo -e "${green}Running $@\n${dots}"
    $@
    echo
  '';
in writeShellScriptBin "update-all" ''
  ${echoAndRun} nix flake update
  find . -name update-sources.sh -execdir sh -c '${echoAndRun} "$(realpath {})"&& echo' \;
  find . -name update.sh -execdir sh -c '${echoAndRun} "$(realpath {})"&& echo' \;
''
