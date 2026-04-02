#!/usr/bin/env bash
#
# Build and export a signed App Store archive after validating the submission
# manifest. This script intentionally stops short of automatic upload because
# the remaining review/privacy/compliance steps still live in App Store Connect.
#
# Usage:
#   ./scripts/appstore/archive-and-upload.sh [--skip-generate] [--skip-archive] [--skip-export]
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/tooling/common.sh"

: "${SUNCLUB_FLAVOR:=prod}"
setup_local_tooling_env

WORKSPACE="$ROOT_DIR/$APP_WORKSPACE"
SCHEME="$APP_SCHEME"
ARCHIVE_OUTPUT_PATH="$ARCHIVE_PATH"
EXPORT_OUTPUT_PATH="$EXPORT_PATH"
EXPORT_OPTIONS_PATHNAME="$ROOT_DIR/$EXPORT_OPTIONS_PATH"
ARCHIVE_DERIVED_DATA_PATH="$ROOT_DIR/$ARCHIVE_DERIVED_DATA"
APPLE_TEAM_ID="$TEAM_ID"

SKIP_GENERATE=false
SKIP_ARCHIVE=false
SKIP_EXPORT=false

for arg in "$@"; do
  case "$arg" in
  --skip-generate) SKIP_GENERATE=true ;;
  --skip-archive) SKIP_ARCHIVE=true ;;
  --skip-export) SKIP_EXPORT=true ;;
  *)
    printf 'Unknown argument: %s\n' "$arg" >&2
    exit 2
    ;;
  esac
done

step() { printf '\n\033[1;33m→ %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
fail() {
  printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2
  exit 1
}

[ -f "$EXPORT_OPTIONS_PATHNAME" ] || fail "Missing export options: $EXPORT_OPTIONS_PATHNAME"
command -v xcodebuild >/dev/null || fail "xcodebuild is required."
command -v xcrun >/dev/null || fail "xcrun is required."

step "Validating App Store metadata"
run_repo_python_module scripts.appstore.validate_metadata "scripts/appstore/metadata.json"
ok "Submission manifest is valid"

if [ "$SKIP_GENERATE" = false ]; then
  step "Generating the Tuist workspace"
  generate_workspace
  ok "Workspace generated"
else
  ok "Skipping workspace generation"
fi

if [ "$SKIP_ARCHIVE" = false ]; then
  step "Archiving the signed release build"
  rm -rf "$ARCHIVE_OUTPUT_PATH" "$ARCHIVE_DERIVED_DATA_PATH"

  xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_OUTPUT_PATH" \
    -derivedDataPath "$ARCHIVE_DERIVED_DATA_PATH" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    CODE_SIGN_STYLE=Automatic

  ok "Archive created at $ARCHIVE_OUTPUT_PATH"
else
  ok "Skipping archive build"
fi

APP_BUNDLE="$ARCHIVE_OUTPUT_PATH/Products/Applications/Sunclub.app"
[ -d "$APP_BUNDLE" ] || fail "Archive is missing $APP_BUNDLE"

if [ "$SKIP_EXPORT" = false ]; then
  step "Exporting the App Store package"
  rm -rf "$EXPORT_OUTPUT_PATH"

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_OUTPUT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATHNAME" \
    -exportPath "$EXPORT_OUTPUT_PATH"

  IPA_FILE="$(find "$EXPORT_OUTPUT_PATH" -name '*.ipa' -print -quit)"
  [ -n "$IPA_FILE" ] || fail "No IPA was exported to $EXPORT_OUTPUT_PATH"
  ok "Exported IPA: $IPA_FILE"
else
  ok "Skipping IPA export"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Archive flow completed.

Next manual steps:
1. Replace the draft URLs and review contact fields in scripts/appstore/metadata.json.
2. Capture the 6.9-inch iPhone screenshots with scripts/appstore/capture-screenshots.sh.
3. Upload the screenshots and IPA in App Store Connect / Transporter.
4. Complete App Privacy and export compliance answers in App Store Connect.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
