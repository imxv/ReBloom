#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly manifest_path="$repository_root/Adonis/Resources/Samples/regression-baseline.json"
readonly generator_path="$repository_root/scripts/generate_sample_stickers.swift"
readonly sample_directory="$repository_root/Adonis/Resources/Samples"

if [[ ! -f "$manifest_path" || ! -f "$generator_path" ]]; then
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
