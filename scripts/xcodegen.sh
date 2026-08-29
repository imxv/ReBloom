#!/bin/zsh

set -euo pipefail

readonly XCODEGEN_VERSION="2.46.0"
readonly REPOSITORY_ROOT="${0:A:h:h}"
readonly TOOL_ROOT="$REPOSITORY_ROOT/.tools/xcodegen-$XCODEGEN_VERSION"
readonly TOOL_BINARY="$TOOL_ROOT/xcodegen/bin/xcodegen"

if [[ ! -x "$TOOL_BINARY" ]]; then
  readonly DOWNLOAD_DIR="$(mktemp -d)"
  trap 'rm -rf "$DOWNLOAD_DIR"' EXIT

  curl -fL --retry 2 \
    --output "$DOWNLOAD_DIR/xcodegen.zip" \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
  mkdir -p "$TOOL_ROOT"
  unzip -q "$DOWNLOAD_DIR/xcodegen.zip" -d "$TOOL_ROOT"
fi

exec "$TOOL_BINARY" "$@"
