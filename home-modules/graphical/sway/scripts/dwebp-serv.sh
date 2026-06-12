#! /usr/bin/env nix-shell
#! nix-shell -i bash -p libwebp inotify-tools

# This script automatically converts all .webp files in the home and ~/images
# directories to .png files. It can be run in the background as a service.

searchDirs=(~ ~/images)

function convertFiles(){
  find -L "${searchDirs[@]}" -maxdepth 1 -name "*.webp" | while read -r file; do
    if [ -f "${file%.webp}.png" ]; then
      continue
    fi
    dwebp "$file" -o "${file%.webp}.png"
    # rm "$file"
  done
}

while true; do
  inotifywait -e create,modify "${searchDirs[@]}" && \
    convertFiles
done
