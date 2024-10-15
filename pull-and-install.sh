#!/usr/bin/env bash

set -e

if [[ "$1" == "-x" ]]; then
  set -x
  shift
fi

dir="$(dirname "$0")"

api="https://api.github.com"
user="reedrw"
repo="nix-config"

mainUrl="$api/repos/$user/$repo"

# Get latest reedbot PR numbers
PRs=$(curl -s "$mainUrl/pulls" | jq -r '.[] | select(.user.login == "reedbot[bot]") | .number')

mergePr(){
  for prNumber in $PRs; do
    # Get PR ref
    prRef="$(curl -s "$mainUrl/pulls/$prNumber" | jq -r '.head.sha')"

    # Get GitHub Action workflow conclusion
    prConclusion="$(curl -s "$mainUrl/commits/$prRef/check-suites" | jq -r '.check_suites[] | select(.app.slug == "github-actions") | .conclusion')"

    if [[ $prConclusion == "success" ]]; then
      gh pr view "$prNumber" --comments
      read -rp "Merge and install PR? (Y/n) " yn
      case $yn in
        [nN])
          exit 2
        ;;
        *)
          gh pr merge "$prNumber" -dm && git pull
          ./install.sh "$@"
          break
        ;;
      esac
    fi
  done
}

pushd "$dir" > /dev/null || exit
clonedCommitSha="$(git rev-parse main)"
upstreamCommitSha="$(curl -s "$mainUrl/branches" | jq -r '.[] | select(.name == "main") | .commit.sha')"
if [[ "$clonedCommitSha" == "$upstreamCommitSha" ]]; then
  mergePr "$@"
else
  git pull --rebase
  ./install.sh "$@"
fi
popd >> /dev/null || exit
