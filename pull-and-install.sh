#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq gh git curl

set -e
set -x

api="https://api.github.com"
user="reedrw"
repo="nix-config"

mainUrl="$api/repos/$user/$repo"

# Get latest reedbot PR number
prNumber="$(curl -s "$mainUrl/pulls" | jq -r '.[] | select(.user.login == "reedbot[bot]") | .number')"

# Get PR ref
prRef="$(curl -s "$mainUrl/pulls/$prNumber" | jq -r '.head.sha')"

# Get GitHub Action workflow conclusion
prConclusion="$(curl -s "$mainUrl/commits/$prRef/check-suites" | jq -r '.check_suites[] | select(.app.slug == "github-actions") | .conclusion')"

main(){
  if [[ $prConclusion == "success" ]]; then
    pushd ~/.config/nixpkgs || exit
    gh pr merge "$prNumber" -dm
    git pull
    ./install.sh
    popd || exit
  else
    exit 1
  fi
}

main "$@"
