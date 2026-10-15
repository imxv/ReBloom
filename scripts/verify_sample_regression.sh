#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly manifest_path="$repository_root/Adonis/Resources/Samples/regression-baseline.json"
readonly homepage_manifest_path="$repository_root/Adonis/Resources/Samples/homepage-ai-showcase.json"
readonly generator_path="$repository_root/scripts/generate_sample_stickers.swift"
readonly homepage_generator_path="$repository_root/scripts/generate_homepage_ai_sticker.sh"
readonly sample_directory="$repository_root/Adonis/Resources/Samples"

if [[ ! -f "$manifest_path" || ! -f "$homepage_manifest_path" || ! -f "$generator_path" \
  || ! -x "$homepage_generator_path" ]]; then
  echo "Sample regression inputs are missing." >&2
  exit 1
fi

temporary_directory="$(/usr/bin/mktemp -d /tmp/adonis-sample-regression.XXXXXX)"
cleanup() {
  if [[ -n "$temporary_directory" && "$temporary_directory" == /tmp/adonis-sample-regression.* && -d "$temporary_directory" ]]; then
    /bin/rm -rf -- "$temporary_directory"
  fi
}
trap cleanup EXIT

declare -a sample_ids sticker_names process_ids
sample_count=0

while sample_id="$(
  /usr/bin/plutil -extract "samples.$sample_count.id" raw -o - "$manifest_path" 2>/dev/null
)"; do
  source_name="$(
    /usr/bin/plutil -extract "samples.$sample_count.source.resourceName" raw -o - "$manifest_path"
  )"
  sticker_name="$(
    /usr/bin/plutil -extract "samples.$sample_count.sticker.resourceName" raw -o - "$manifest_path"
  )"
  expected_source_hash="$(
    /usr/bin/plutil -extract "samples.$sample_count.source.sha256" raw -o - "$manifest_path"
  )"
  expected_sticker_hash="$(
    /usr/bin/plutil -extract "samples.$sample_count.sticker.sha256" raw -o - "$manifest_path"
  )"

  if [[ "$source_name" == */* || "$sticker_name" == */* ]]; then
    echo "Manifest resource names must be plain file names: $sample_id" >&2
    exit 1
  fi

  source_path="$sample_directory/$source_name"
  sticker_path="$sample_directory/$sticker_name"
  actual_source_hash="$(/usr/bin/shasum -a 256 "$source_path" | /usr/bin/awk '{print $1}')"
  actual_sticker_hash="$(/usr/bin/shasum -a 256 "$sticker_path" | /usr/bin/awk '{print $1}')"

  if [[ "$actual_source_hash" != "$expected_source_hash" ]]; then
    echo "$sample_id source hash changed: $actual_source_hash" >&2
    exit 1
  fi
  if [[ "$actual_sticker_hash" != "$expected_sticker_hash" ]]; then
    echo "$sample_id sticker hash changed: $actual_sticker_hash" >&2
    exit 1
  fi

  sample_ids[$sample_count]="$sample_id"
  sticker_names[$sample_count]="$sticker_name"
  /usr/bin/xcrun swift "$generator_path" "$source_path" "$temporary_directory/$sticker_name" \
    >"$temporary_directory/$sample_id.log" 2>&1 &
  process_ids[$sample_count]=$!
  sample_count=$((sample_count + 1))
done

if [[ "$sample_count" -ne 4 ]]; then
  echo "Expected exactly four authorized samples, found $sample_count." >&2
  exit 1
fi

generation_failed=0
for ((index = 0; index < sample_count; index++)); do
  if ! wait "${process_ids[$index]}"; then
    generation_failed=1
  fi
done

if [[ "$generation_failed" -ne 0 ]]; then
  for ((index = 0; index < sample_count; index++)); do
    log_path="$temporary_directory/${sample_ids[$index]}.log"
    if [[ -s "$log_path" ]]; then
      echo "--- ${sample_ids[$index]} ---" >&2
      /bin/cat "$log_path" >&2
    fi
  done
  exit 1
fi

for ((index = 0; index < sample_count; index++)); do
  sample_id="${sample_ids[$index]}"
  sticker_name="${sticker_names[$index]}"
  committed_sticker="$sample_directory/$sticker_name"
  regenerated_sticker="$temporary_directory/$sticker_name"

  if ! /usr/bin/cmp -s "$committed_sticker" "$regenerated_sticker"; then
    regenerated_hash="$(/usr/bin/shasum -a 256 "$regenerated_sticker" | /usr/bin/awk '{print $1}')"
    echo "$sample_id regenerated sticker differs: $regenerated_hash" >&2
    exit 1
  fi

  echo "Verified $sample_id: source hash, sticker hash, and byte-identical regeneration."
done

homepage_sample_count=0
while homepage_sample_id="$(
  /usr/bin/plutil -extract "samples.$homepage_sample_count.id" raw -o - \
    "$homepage_manifest_path" 2>/dev/null
)"; do
  homepage_source_name="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.aiSource.resourceName" raw -o - \
      "$homepage_manifest_path"
  )"
  homepage_sticker_name="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.sticker.resourceName" raw -o - \
      "$homepage_manifest_path"
  )"
  homepage_chroma_relative_path="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.chroma.path" raw -o - \
      "$homepage_manifest_path"
  )"
  expected_homepage_source_hash="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.aiSource.sha256" raw -o - \
      "$homepage_manifest_path"
  )"
  expected_homepage_sticker_hash="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.sticker.sha256" raw -o - \
      "$homepage_manifest_path"
  )"
  expected_homepage_chroma_hash="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.chroma.sha256" raw -o - \
      "$homepage_manifest_path"
  )"

  if [[ "$homepage_source_name" == */* || "$homepage_sticker_name" == */* \
    || "$homepage_chroma_relative_path" != assets/prototypes/digital-figurine-sticker/* ]]; then
    echo "Homepage sample paths are outside their allowed directories: $homepage_sample_id" >&2
    exit 1
  fi

  homepage_source_path="$sample_directory/$homepage_source_name"
  homepage_sticker_path="$sample_directory/$homepage_sticker_name"
  homepage_chroma_path="$repository_root/$homepage_chroma_relative_path"
  actual_homepage_source_hash="$(
    /usr/bin/shasum -a 256 "$homepage_source_path" | /usr/bin/awk '{print $1}'
  )"
  actual_homepage_sticker_hash="$(
    /usr/bin/shasum -a 256 "$homepage_sticker_path" | /usr/bin/awk '{print $1}'
  )"
  actual_homepage_chroma_hash="$(
    /usr/bin/shasum -a 256 "$homepage_chroma_path" | /usr/bin/awk '{print $1}'
  )"

  if [[ "$actual_homepage_source_hash" != "$expected_homepage_source_hash" ]]; then
    echo "$homepage_sample_id homepage AI source hash changed: $actual_homepage_source_hash" >&2
    exit 1
  fi
  if [[ "$actual_homepage_sticker_hash" != "$expected_homepage_sticker_hash" ]]; then
    echo "$homepage_sample_id homepage AI sticker hash changed: $actual_homepage_sticker_hash" >&2
    exit 1
  fi
  if [[ "$actual_homepage_chroma_hash" != "$expected_homepage_chroma_hash" ]]; then
    echo "$homepage_sample_id homepage chroma hash changed: $actual_homepage_chroma_hash" >&2
    exit 1
  fi

  background_red="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.chroma.backgroundRed" raw -o - \
      "$homepage_manifest_path"
  )"
  background_green="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.chroma.backgroundGreen" raw -o - \
      "$homepage_manifest_path"
  )"
  background_blue="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.chroma.backgroundBlue" raw -o - \
      "$homepage_manifest_path"
  )"
  transparent_threshold="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.chroma.transparentThreshold" raw -o - \
      "$homepage_manifest_path"
  )"
  threshold_span="$(
    /usr/bin/plutil -extract "samples.$homepage_sample_count.chroma.thresholdSpan" raw -o - \
      "$homepage_manifest_path"
  )"
  regenerated_homepage_sticker="$temporary_directory/homepage-$homepage_sticker_name"

  "$homepage_generator_path" \
    "$homepage_chroma_path" \
    "$regenerated_homepage_sticker" \
    "$background_red" \
    "$background_green" \
    "$background_blue" \
    "$transparent_threshold" \
    "$threshold_span"

  if ! /usr/bin/cmp -s "$homepage_sticker_path" "$regenerated_homepage_sticker"; then
    regenerated_homepage_hash="$(
      /usr/bin/shasum -a 256 "$regenerated_homepage_sticker" | /usr/bin/awk '{print $1}'
    )"
    echo "$homepage_sample_id regenerated homepage sticker differs: $regenerated_homepage_hash" >&2
    exit 1
  fi

  echo "Verified $homepage_sample_id homepage AI source, chroma input, real-Alpha sticker, and byte-identical post-processing."
  homepage_sample_count=$((homepage_sample_count + 1))
done

if [[ "$homepage_sample_count" -ne 3 ]]; then
  echo "Expected exactly three homepage AI samples, found $homepage_sample_count." >&2
  exit 1
fi
