#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data="$repository_root/.derivedData-legacy-provider-disabled"
readonly binary_path="$derived_data/Build/Products/Release-iphoneos/ReBloom.app/ReBloom"
readonly release_build_log="$derived_data/release-build.log"
readonly runtime_test_log="$derived_data/runtime-test.log"

mkdir -p "$derived_data"

if ! xcodebuild \
  -project "$repository_root/ReBloom.xcodeproj" \
  -scheme ReBloom \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data" \
  clean build \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=ADONIS_LEGACY_PROVIDER_DISABLED \
  >"$release_build_log" 2>&1
then
  tail -n 120 "$release_build_log" >&2
  exit 1
fi

if [[ ! -x "$binary_path" ]]; then
  echo "Legacy-disabled Release binary is missing." >&2
  exit 1
fi

if ! /usr/bin/otool -L "$binary_path" | rg -q 'ImagePlayground\.framework'; then
  echo "Legacy-disabled Release binary is missing the supported Image Playground sheet." >&2
  exit 1
fi

if /usr/bin/nm -u "$binary_path" | rg -q 'ImageCreator'; then
  echo "Legacy-disabled Release binary still imports ImageCreator symbols." >&2
  exit 1
fi

if ! xcodebuild \
  -project "$repository_root/ReBloom.xcodeproj" \
  -scheme ReBloom \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath "$derived_data" \
  test \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG ADONIS_LEGACY_PROVIDER_DISABLED' \
  -only-testing:ReBloomTests/CreativeExecutionMetadataTests/testSystemGeneratorIsHonestlyUnavailableWithoutLegacyImageCreator \
  >"$runtime_test_log" 2>&1
then
  tail -n 120 "$runtime_test_log" >&2
  exit 1
fi

echo "Verified provider boundary: the supported Image Playground sheet remains linked, legacy ImageCreator symbols are absent, and the old programmatic generator reports unavailable."
