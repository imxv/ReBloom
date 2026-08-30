#!/bin/zsh

set -euo pipefail

task_script_dir=${0:A:h}
task_project_root=${task_script_dir:h}
task_device_id=${ADONIS_ACCESSIBILITY_DEVICE_ID:-}
task_booted_by_script=0
task_previous_size=""
task_previous_contrast=""

if [[ -z "$task_device_id" ]]; then
  task_device_id=$(
    xcrun simctl list devices available \
      | rg '^[[:space:]]*iPhone 17 Pro \(' \
      | head -n 1 \
      | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
  )
fi

if [[ -z "$task_device_id" ]]; then
  print -u2 "没有找到可用的 iPhone 17 Pro 模拟器。"
  exit 1
fi

if ! xcrun simctl list devices booted | rg -q "$task_device_id"; then
  xcrun simctl boot "$task_device_id"
  xcrun simctl bootstatus "$task_device_id" -b
  task_booted_by_script=1
fi

task_previous_size=$(xcrun simctl ui "$task_device_id" content_size)
task_previous_contrast=$(xcrun simctl ui "$task_device_id" increase_contrast)

function task_restore_simulator_settings {
  if [[ -n "$task_previous_size" ]]; then
    xcrun simctl ui "$task_device_id" content_size "$task_previous_size" >/dev/null || true
  fi
  if [[ -n "$task_previous_contrast" ]]; then
    xcrun simctl ui "$task_device_id" increase_contrast "$task_previous_contrast" >/dev/null \
      || true
  fi
  if (( task_booted_by_script )); then
    xcrun simctl shutdown "$task_device_id" >/dev/null || true
  fi
}

trap task_restore_simulator_settings EXIT INT TERM

xcrun simctl ui "$task_device_id" content_size accessibility-extra-extra-extra-large
xcrun simctl ui "$task_device_id" increase_contrast enabled

task_active_size=$(xcrun simctl ui "$task_device_id" content_size)
task_active_contrast=$(xcrun simctl ui "$task_device_id" increase_contrast)
if [[ "$task_active_size" != "accessibility-extra-extra-extra-large" ]]; then
  print -u2 "辅助字号没有生效：$task_active_size"
  exit 1
fi
if [[ "$task_active_contrast" != "enabled" ]]; then
  print -u2 "增强对比度没有生效：$task_active_contrast"
  exit 1
fi

print "辅助字号：$task_active_size"
print "增强对比度：$task_active_contrast"

cd "$task_project_root"
xcodebuild \
  -project Adonis.xcodeproj \
  -scheme Adonis \
  -destination "platform=iOS Simulator,id=$task_device_id" \
  -derivedDataPath .derivedData \
  test \
  -only-testing:AdonisTests/AccessibilityContractTests \
  -only-testing:AdonisUITests/AdonisFlowUITests/testAccessibleCoreFlowSurvivesBackgroundAndKeepsActionsReachable \
  -only-testing:AdonisUITests/AdonisFlowUITests/testGeneratedStickerCreatesTraceableBotanicalPosterReadyToCompareSaveAndShare \
  -only-testing:AdonisUITests/AdonisFlowUITests/testConfirmedPiecesFromDifferentOutfitsCreateShareableRebloomSuggestion \
  -only-testing:AdonisUITests/AdonisFlowUITests/testProcessingOverlayKeepsCancelReachable
