#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo >&2 "Usage: swap_mochi_cats <sigstick pack id>"
  exit 1
fi

if ! [ -z "$(ls)" ]; then
  echo >&2 "ERROR: The current directory is not empty! Please run this script in a new folder."
  exit 1
fi

id="$1"

download_sticker_pack() {
  local id="$1"
  local urls filenames

  urls=$(curl "https://www.sigstick.com/pack/$id" |
    grep -Eo "\"url\":\"https://storage.googleapis.com/sticker-prod/$id/[^\"]+\.(png|webp)\"" |
    sed 's|"url":"||g' |
    tr -d '"' |
    grep -v cover)
  filenames=$(echo "$urls" | xargs -n1 basename)
  echo "$urls" | xargs -n1 -P100 wget

  echo "$filenames"
}

process_sticker() {
  local sticker="$1"
  local name
  local ext

  name=${sticker%.*}
  ext=${sticker##*.}

  # Extract frames into a child folder, depending on extension
  if [ "$ext" = "png" ]; then
    # apng -> png
    apngasm -o "$name" -D "$sticker"
  elif [ "$ext" = "webp" ]; then
    # webp -> png
    mkdir "$name"
    anim_dump -folder "$name" -prefix "" "$sticker"
  fi

  rm "$sticker"
  for f in "$name"/*.png; do
    mv "$f" "$name"/$(basename "$f" ".png" | xargs printf "%05d").png
  done

  # Swap mochi colors
  for f in "$name"/*.png; do
    mv "$f" "$f.out.png"
    convert "$f.out.png" -resize 512x512^ -background none -gravity center -extent 512x512 "$f.out.png"
    convert "$f.out.png" -fuzz 3% -fill '#a06b32' -opaque '#fae2d8' "$f.out.png"  # pink shadow
    convert "$f.out.png" -fuzz 5% -fill '#303b6a' -opaque '#ac9b93' "$f.out.png"  # grey shadow
    convert "$f.out.png" -fuzz 10% -fill '#5537a1' -opaque '#c3b9b1' "$f.out.png" # grey
    convert "$f.out.png" -fuzz 5% -fill '#c3b9b1' -opaque white "$f.out.png"
    convert "$f.out.png" -fill '#f7e4dd' -opaque '#303b6a' "$f.out.png"
    convert "$f.out.png" -fill 'white' -opaque '#5537a1' "$f.out.png"
    convert "$f.out.png" -fill '#ac9f95' -opaque '#a06b32' "$f.out.png"
    convert "$f.out.png" -negate -morphology dilate rectangle:2x2 -negate "$f.out.png" # remove white edges
    convert "$f.out.png" -resize 256x256 "$f.out.png"
    pngquant -f --ext .png --quality 0-50 "$f.out.png"
  done

  # Reassemble apng from frames
  apngasm -o "$name.apng" "$name"/*.out.png

  # Delete created subfolders
  rm -r "$name"
}

main() {
  local id="$1"
  local stickers multiprocess

  stickers=$(download_sticker_pack "$id")
  multiprocess=$(getconf _NPROCESSORS_ONLN)

  export -f process_sticker
  echo "$stickers" | xargs -n1 -P "$multiprocess" sh -c "process_sticker \$0"
}

main "$id"
