#!/bin/bash

set -euo pipefail

if [[ "$#" -ne 7 ]]; then
  echo "Usage: $0 <chroma-input> <output> <background-r> <background-g> <background-b> <transparent-threshold> <threshold-span>" >&2
  exit 64
fi

readonly chroma_input="$1"
readonly output_path="$2"
readonly background_red="$3"
readonly background_green="$4"
readonly background_blue="$5"
readonly transparent_threshold="$6"
readonly threshold_span="$7"

if [[ ! -f "$chroma_input" ]]; then
  echo "Chroma input is missing: $chroma_input" >&2
  exit 66
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required to convert the reviewed chroma asset to genuine Alpha." >&2
  exit 69
fi

readonly temporary_directory="$(/usr/bin/mktemp -d /tmp/adonis-homepage-ai-sticker.XXXXXX)"
cleanup() {
  if [[ "$temporary_directory" == /tmp/adonis-homepage-ai-sticker.* && -d "$temporary_directory" ]]; then
    /bin/rm -rf -- "$temporary_directory"
  fi
}
trap cleanup EXIT

readonly raw_alpha_path="$temporary_directory/raw-alpha.png"
readonly decontaminated_path="$temporary_directory/decontaminated.png"

magick "$chroma_input" \
  \( +clone -alpha off \
    -fx "max(0,min(1,($transparent_threshold-(u.g-max(u.r,u.b)))/$threshold_span))" \) \
  -alpha off -compose CopyOpacity -composite "$raw_alpha_path"

magick "$raw_alpha_path" \
  -channel R \
  -fx "u.a<0.01?0:max(0,min(1,(u.r-(1-u.a)*$background_red)/u.a))" +channel \
  -channel G \
  -fx "u.a<0.01?0:max(0,min(1,(u.g-(1-u.a)*$background_green)/u.a))" +channel \
  -channel B \
  -fx "u.a<0.01?0:max(0,min(1,(u.b-(1-u.a)*$background_blue)/u.a))" +channel \
  "$decontaminated_path"

magick "$decontaminated_path" \
  -shave 2x2 \
  -channel A -fx 'u<0.03?0:u' +channel \
  \( +clone -fill white -colorize 100 \
    -channel A -morphology Dilate Disk:14 +channel \) \
  +swap -compose Over -composite \
  -trim +repage -bordercolor none -border 18 \
  -resize '1536x1536' \
  -strip \
  "$output_path"
