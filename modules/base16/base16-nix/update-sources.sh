#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash curl gnused gron jq nix-prefetch-git

# Run from within the directory which needs the templates.json/schemes.json

# Not very safe - should be cleaner & could be more parallel
# should always be permitted to run to completion

generate_sources () {
  out=$1
  curl "https://raw.githubusercontent.com/chriskempson/base16-${out}-source/master/list.yaml"\
  | sed -nE "s~^([-_[:alnum:]]+): *(.*)~\1 \2~p"\
  | while read -r name src; do
      echo "{\"key\":\"$name\",\"value\":"
      nix-prefetch-git "$src"
      echo "}"
    done\
  | jq -s ".|del(.[].value.date)|from_entries"\
  > "$out".json
}

generate_sources templates &
generate_sources schemes &
wait

mv -v templates.json templates.old.json
mv -v schemes.json schemes.old.json
gron templates.old.json | grep 'url\|rev\|sha256\|fetchSubmodules' | gron --ungron > templates.json
gron schemes.old.json | grep 'url\|rev\|sha256\|fetchSubmodules' | gron --ungron > schemes.json
rm -v templates.old.json
rm -v schemes.old.json
