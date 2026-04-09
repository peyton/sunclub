#!/usr/bin/env bash
#
# Build and export a signed App Store archive after validating the submission
# manifest. Optionally upload the exported IPA to TestFlight.
#
# Usage:
#   ./scripts/appstore/archive-and-upload.sh [--allow-draft-metadata] [--skip-generate] [--skip-archive] [--skip-export] [--upload-testflight]
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/tooling/common.sh"

: "${SUNCLUB_FLAVOR:=prod}"
setup_local_tooling_env

WORKSPACE="$ROOT_DIR/$APP_WORKSPACE"
SCHEME="$RELEASE_APP_SCHEME"
ARCHIVE_OUTPUT_PATH="$ARCHIVE_PATH"
EXPORT_OUTPUT_PATH="$EXPORT_PATH"
EXPORT_OPTIONS_PATHNAME="$ROOT_DIR/$EXPORT_OPTIONS_PATH"
ARCHIVE_DERIVED_DATA_PATH="$ROOT_DIR/$ARCHIVE_DERIVED_DATA"
APPLE_TEAM_ID="$TEAM_ID"
APP_BUNDLE_PATH="$ARCHIVE_OUTPUT_PATH/Products/Applications/$RELEASE_APP_PRODUCT_NAME.app"

SKIP_GENERATE=false
SKIP_ARCHIVE=false
SKIP_EXPORT=false
UPLOAD_TESTFLIGHT=false
ALLOW_DRAFT_METADATA=false

for arg in "$@"; do
  case "$arg" in
  --allow-draft-metadata) ALLOW_DRAFT_METADATA=true ;;
  --skip-generate) SKIP_GENERATE=true ;;
  --skip-archive) SKIP_ARCHIVE=true ;;
  --skip-export) SKIP_EXPORT=true ;;
  --upload-testflight) UPLOAD_TESTFLIGHT=true ;;
  *)
    printf 'Unknown argument: %s\n' "$arg" >&2
    exit 2
    ;;
  esac
done

XCODEBUILD_AUTH_ARGS=()
if has_app_store_connect_auth; then
  XCODEBUILD_AUTH_ARGS=(
    -authenticationKeyPath "$ASC_KEY_FILE"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

XCODEBUILD_COMPILE_CACHE_ARGS=()
if should_disable_swift_compile_cache; then
  printf 'Disabling compiler caches for this archive build.\n'
  XCODEBUILD_COMPILE_CACHE_ARGS=(
    SWIFT_ENABLE_COMPILE_CACHE=NO
    COMPILATION_CACHE_ENABLE_CACHING=NO
    COMPILATION_CACHE_ENABLE_PLUGIN=NO
    COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=NO
    COMPILATION_CACHE_KEEP_CAS_DIRECTORY=NO
    COMPILATION_CACHE_REMOTE_SERVICE_PATH=
  )
fi

step() { printf '\n\033[1;33m→ %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
fail() {
  printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2
  exit 1
}

[ -f "$EXPORT_OPTIONS_PATHNAME" ] || fail "Missing export options: $EXPORT_OPTIONS_PATHNAME"
command -v xcodebuild >/dev/null || fail "xcodebuild is required."
command -v xcrun >/dev/null || fail "xcrun is required."

if [ "$UPLOAD_TESTFLIGHT" = true ] && [ "$SKIP_EXPORT" = true ]; then
  fail "--upload-testflight requires IPA export"
fi

step "Validating App Store metadata"
metadata_args=("scripts/appstore/metadata.json")
if [ "$ALLOW_DRAFT_METADATA" = true ]; then
  metadata_args=(--allow-draft "${metadata_args[@]}")
fi
run_repo_python_module scripts.appstore.validate_metadata "${metadata_args[@]}"
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
    -allowProvisioningUpdates \
    "${XCODEBUILD_AUTH_ARGS[@]}" \
    "${XCODEBUILD_COMPILE_CACHE_ARGS[@]}" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    CODE_SIGN_STYLE=Automatic

  ok "Archive created at $ARCHIVE_OUTPUT_PATH"
else
  ok "Skipping archive build"
fi

[ -d "$APP_BUNDLE_PATH" ] || fail "Archive is missing $APP_BUNDLE_PATH"

IPA_FILE=""
if [ "$SKIP_EXPORT" = false ]; then
  step "Exporting the App Store package"
  rm -rf "$EXPORT_OUTPUT_PATH"

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_OUTPUT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATHNAME" \
    -exportPath "$EXPORT_OUTPUT_PATH" \
    -allowProvisioningUpdates \
    "${XCODEBUILD_AUTH_ARGS[@]}"

  IPA_FILE="$(find "$EXPORT_OUTPUT_PATH" -name '*.ipa' -print -quit)"
  [ -n "$IPA_FILE" ] || fail "No IPA was exported to $EXPORT_OUTPUT_PATH"
  ok "Exported IPA: $IPA_FILE"
else
  ok "Skipping IPA export"
fi

if [ "$UPLOAD_TESTFLIGHT" = true ]; then
  for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_FILE; do
    [ -n "${!var:-}" ] || fail "Missing environment variable for TestFlight upload: $var"
  done
  [ -f "$ASC_KEY_FILE" ] || fail "App Store Connect key file not found: $ASC_KEY_FILE"

  step "Uploading IPA to TestFlight"
  if xcrun --find altool >/dev/null 2>&1; then
    ALTOOL_LOG_PATH="$(mktemp "${TMPDIR:-/tmp}/sunclub-altool.XXXXXX.log")"
    trap 'rm -f "$ALTOOL_LOG_PATH"' EXIT

    set +e
    xcrun altool \
      --upload-package "$IPA_FILE" \
      --api-key "$ASC_KEY_ID" \
      --api-issuer "$ASC_ISSUER_ID" \
      --p8-file-path "$ASC_KEY_FILE" \
      --show-progress \
      --wait \
      --output-format normal 2>&1 | tee "$ALTOOL_LOG_PATH"
    altool_status=${PIPESTATUS[0]}
    set -e

    if [ "$altool_status" -ne 0 ] ||
      grep -Eq '(^|[[:space:]])ERROR:|UPLOAD FAILED|Validation failed \([0-9]+\)|STATE_ERROR\.' "$ALTOOL_LOG_PATH"; then
      fail "App Store Connect upload failed"
    fi
  else
    TRANSPORTER_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sunclub-transporter.XXXXXX")"
    trap 'rm -rf "$TRANSPORTER_TMP_DIR"' EXIT

    mkdir -p "$TRANSPORTER_TMP_DIR/private_keys"
    cp "$ASC_KEY_FILE" "$TRANSPORTER_TMP_DIR/private_keys/AuthKey_${ASC_KEY_ID}.p8"

    (
      cd "$TRANSPORTER_TMP_DIR"
      xcrun iTMSTransporter \
        -m upload \
        -assetFile "$IPA_FILE" \
        -apiKey "$ASC_KEY_ID" \
        -apiIssuer "$ASC_ISSUER_ID" \
        -apiKeyType team \
        -v informational
    )
  fi

  ok "Submitted IPA to App Store Connect"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Archive flow completed.

Resolved versions:
- MARKETING_VERSION=$SUNCLUB_MARKETING_VERSION
- CFBundleVersion=$SUNCLUB_BUILD_NUMBER

Next manual steps:
1. Replace the draft URLs and review contact fields in scripts/appstore/metadata.json.
2. Capture the 6.9-inch iPhone screenshots with scripts/appstore/capture-screenshots.sh.
3. Upload the screenshots in App Store Connect.
4. Complete App Privacy and export compliance answers in App Store Connect.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
