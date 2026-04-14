#!/usr/bin/env bash
#
# Build an archive, export it as a signed App Store package, and
# optionally upload the exported IPA to TestFlight.
#
# Usage:
#   ./scripts/appstore/archive-and-upload.sh [--allow-draft-metadata] [--skip-generate] [--skip-archive] [--skip-export] [--unsigned-archive] [--upload-testflight]
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/tooling/common.sh"

: "${SUNCLUB_FLAVOR:=prod}"
: "${SUNCLUB_APS_ENVIRONMENT:=production}"
setup_local_tooling_env

WORKSPACE="$ROOT_DIR/$APP_WORKSPACE"
SCHEME="$RELEASE_APP_SCHEME"
ARCHIVE_OUTPUT_PATH="$ARCHIVE_PATH"
EXPORT_OUTPUT_PATH="$EXPORT_PATH"
EXPORT_OPTIONS_PATHNAME="$ROOT_DIR/$EXPORT_OPTIONS_PATH"
ARCHIVE_DERIVED_DATA_PATH="$ROOT_DIR/$ARCHIVE_DERIVED_DATA"
APP_BUNDLE_PATH="$ARCHIVE_OUTPUT_PATH/Products/Applications/$RELEASE_APP_PRODUCT_NAME.app"
RELEASE_DIAGNOSTICS_PATH="${RELEASE_DIAGNOSTICS_PATH:-$ROOT_DIR/.build/release-diagnostics}"
RELEASE_ENTITLEMENTS_PATH="${RELEASE_ENTITLEMENTS_PATH:-$ROOT_DIR/.build/release-entitlements}"

SKIP_GENERATE=false
SKIP_ARCHIVE=false
SKIP_EXPORT=false
UPLOAD_TESTFLIGHT=false
ALLOW_DRAFT_METADATA=false
UNSIGNED_ARCHIVE=false

for arg in "$@"; do
  case "$arg" in
  --allow-draft-metadata) ALLOW_DRAFT_METADATA=true ;;
  --skip-generate) SKIP_GENERATE=true ;;
  --skip-archive) SKIP_ARCHIVE=true ;;
  --skip-export) SKIP_EXPORT=true ;;
  --unsigned-archive) UNSIGNED_ARCHIVE=true ;;
  --upload-testflight) UPLOAD_TESTFLIGHT=true ;;
  *)
    printf 'Unknown argument: %s\n' "$arg" >&2
    exit 2
    ;;
  esac
done

XCODEBUILD_AUTH_ARGS=()
HAS_APP_STORE_CONNECT_AUTH=false
if has_app_store_connect_auth; then
  HAS_APP_STORE_CONNECT_AUTH=true
  XCODEBUILD_AUTH_ARGS=(
    -authenticationKeyPath "$ASC_KEY_FILE"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

XCODEBUILD_COMPILE_CACHE_ARGS=()
DISABLE_SWIFT_COMPILE_CACHE=false
if should_disable_swift_compile_cache; then
  DISABLE_SWIFT_COMPILE_CACHE=true
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

XCODEBUILD_ARCHIVE_PROVISIONING_ARGS=()
XCODEBUILD_ARCHIVE_SIGNING_ARGS=()
if [ "$UNSIGNED_ARCHIVE" = true ]; then
  XCODEBUILD_ARCHIVE_SIGNING_ARGS=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
  )
else
  XCODEBUILD_ARCHIVE_PROVISIONING_ARGS=(
    -allowProvisioningUpdates
  )
  if [ "$HAS_APP_STORE_CONNECT_AUTH" = true ]; then
    XCODEBUILD_ARCHIVE_PROVISIONING_ARGS+=("${XCODEBUILD_AUTH_ARGS[@]}")
  fi
fi

step() { printf '\n\033[1;33m→ %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
fail() {
  printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2
  exit 1
}

assert_plist_string() {
  local plist_path="$1"
  local key="$2"
  local expected="$3"
  local actual

  if ! actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null)"; then
    fail "Signed app is missing entitlement: $key"
  fi
  if [ "$actual" != "$expected" ]; then
    fail "Signed app entitlement $key is '$actual', expected '$expected'"
  fi
}

assert_plist_array_contains() {
  local plist_path="$1"
  local key="$2"
  local expected="$3"

  if ! /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null |
    sed 's/^[[:space:]]*//' |
    grep -Fxq "$expected"; then
    fail "Signed app entitlement $key does not contain '$expected'"
  fi
}

validate_signed_ipa_entitlements() {
  local ipa_file="$1"
  local temp_dir
  local signed_app_path
  local entitlements_path
  local expected_container
  local expected_app_group

  command -v codesign >/dev/null || fail "codesign is required."
  command -v unzip >/dev/null || fail "unzip is required."
  [ -x /usr/libexec/PlistBuddy ] || fail "PlistBuddy is required."

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/sunclub-ipa.XXXXXX")"
  unzip -q "$ipa_file" -d "$temp_dir"
  signed_app_path="$(find "$temp_dir/Payload" -maxdepth 1 -name "$RELEASE_APP_PRODUCT_NAME.app" -type d -print -quit)"
  [ -n "$signed_app_path" ] || fail "Exported IPA is missing $RELEASE_APP_PRODUCT_NAME.app"

  entitlements_path="$temp_dir/entitlements.plist"
  if ! codesign -d --entitlements :- "$signed_app_path" >"$entitlements_path" 2>"$temp_dir/codesign.log"; then
    cat "$temp_dir/codesign.log" >&2
    fail "Could not read signed app entitlements"
  fi

  expected_container="iCloud.$RELEASE_APP_IDENTIFIER"
  expected_app_group="group.$RELEASE_APP_IDENTIFIER"
  assert_plist_string "$entitlements_path" "aps-environment" "$SUNCLUB_APS_ENVIRONMENT"
  assert_plist_string "$entitlements_path" "com.apple.developer.icloud-container-environment" "Production"
  assert_plist_array_contains "$entitlements_path" "com.apple.developer.icloud-services" "CloudKit"
  assert_plist_array_contains \
    "$entitlements_path" \
    "com.apple.developer.icloud-container-identifiers" \
    "$expected_container"
  assert_plist_array_contains \
    "$entitlements_path" \
    "com.apple.security.application-groups" \
    "$expected_app_group"

  rm -rf "$temp_dir"
}

resolve_release_entitlements() {
  local cloudkit_environment
  local app_entitlements_path="$RELEASE_ENTITLEMENTS_PATH/$RELEASE_APP_PRODUCT_NAME.entitlements.plist"
  local widget_entitlements_path="$RELEASE_ENTITLEMENTS_PATH/$RELEASE_APP_PRODUCT_NAME-widget.entitlements.plist"

  cloudkit_environment="Development"
  if [ "$SUNCLUB_APS_ENVIRONMENT" = "production" ]; then
    cloudkit_environment="Production"
  fi

  rm -rf "$RELEASE_ENTITLEMENTS_PATH"
  mkdir -p "$RELEASE_ENTITLEMENTS_PATH"

  run_repo_python_module scripts.appstore.resolve_entitlements \
    --source "$ROOT_DIR/app/Sunclub/Sunclub.entitlements" \
    --output "$app_entitlements_path" \
    --set "SUNCLUB_APS_ENVIRONMENT=$SUNCLUB_APS_ENVIRONMENT" \
    --set "SUNCLUB_ICLOUD_ENVIRONMENT=$cloudkit_environment" \
    --set "SUNCLUB_ICLOUD_CONTAINER=iCloud.$RELEASE_APP_IDENTIFIER" \
    --set "SUNCLUB_APP_GROUP_ID=group.$RELEASE_APP_IDENTIFIER"

  run_repo_python_module scripts.appstore.resolve_entitlements \
    --source "$ROOT_DIR/app/Sunclub/SunclubWidgetsExtension.entitlements" \
    --output "$widget_entitlements_path" \
    --set "SUNCLUB_APP_GROUP_ID=group.$RELEASE_APP_IDENTIFIER"
}

adhoc_sign() {
  local path="$1"
  local entitlements_path="${2:-}"
  local codesign_args=(
    --force
    --sign -
    --timestamp=none
    --generate-entitlement-der
  )

  if [ -n "$entitlements_path" ]; then
    codesign_args+=(--entitlements "$entitlements_path")
  fi

  codesign "${codesign_args[@]}" "$path"
}

adhoc_sign_archived_app_with_release_entitlements() {
  local app_entitlements_path="$RELEASE_ENTITLEMENTS_PATH/$RELEASE_APP_PRODUCT_NAME.entitlements.plist"
  local widget_entitlements_path="$RELEASE_ENTITLEMENTS_PATH/$RELEASE_APP_PRODUCT_NAME-widget.entitlements.plist"
  local nested_path

  command -v codesign >/dev/null || fail "codesign is required."
  resolve_release_entitlements

  while IFS= read -r nested_path; do
    adhoc_sign "$nested_path"
  done < <(find "$APP_BUNDLE_PATH" -type d -name '*.framework' -print)

  while IFS= read -r nested_path; do
    adhoc_sign "$nested_path"
  done < <(find "$APP_BUNDLE_PATH" -type f -name '*.dylib' -print)

  while IFS= read -r nested_path; do
    adhoc_sign "$nested_path" "$widget_entitlements_path"
  done < <(find "$APP_BUNDLE_PATH/PlugIns" -maxdepth 1 -type d -name '*.appex' -print 2>/dev/null || true)

  adhoc_sign "$APP_BUNDLE_PATH" "$app_entitlements_path"
}

write_ipa_entitlement_diagnostics() {
  local ipa_file="$1"
  local temp_dir
  local signed_app_path
  local widget_path
  local archive_signed

  command -v codesign >/dev/null || fail "codesign is required."
  command -v unzip >/dev/null || fail "unzip is required."

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/sunclub-ipa-diagnostics.XXXXXX")"
  unzip -q "$ipa_file" -d "$temp_dir"
  signed_app_path="$(find "$temp_dir/Payload" -maxdepth 1 -name "$RELEASE_APP_PRODUCT_NAME.app" -type d -print -quit)"
  [ -n "$signed_app_path" ] || fail "Exported IPA is missing $RELEASE_APP_PRODUCT_NAME.app"

  rm -rf "$RELEASE_DIAGNOSTICS_PATH"
  mkdir -p "$RELEASE_DIAGNOSTICS_PATH"

  codesign -dvvv "$signed_app_path" >"$RELEASE_DIAGNOSTICS_PATH/$RELEASE_APP_PRODUCT_NAME.codesign.txt" 2>&1
  if ! codesign -d --entitlements :- "$signed_app_path" >"$RELEASE_DIAGNOSTICS_PATH/$RELEASE_APP_PRODUCT_NAME.entitlements.plist" \
    2>"$RELEASE_DIAGNOSTICS_PATH/$RELEASE_APP_PRODUCT_NAME.entitlements.log"; then
    fail "Could not write signed app entitlement diagnostics"
  fi

  widget_path="$(find "$signed_app_path/PlugIns" -maxdepth 1 -name '*.appex' -type d -print -quit 2>/dev/null || true)"
  if [ -n "$widget_path" ]; then
    widget_name="$(basename "$widget_path")"
    codesign -dvvv "$widget_path" >"$RELEASE_DIAGNOSTICS_PATH/$widget_name.codesign.txt" 2>&1
    if ! codesign -d --entitlements :- "$widget_path" >"$RELEASE_DIAGNOSTICS_PATH/$widget_name.entitlements.plist" \
      2>"$RELEASE_DIAGNOSTICS_PATH/$widget_name.entitlements.log"; then
      fail "Could not write widget entitlement diagnostics"
    fi
  fi

  archive_signed="yes"
  if [ "$UNSIGNED_ARCHIVE" = true ]; then
    archive_signed="no"
  fi

  {
    printf 'IPA: %s\n' "$ipa_file"
    printf 'App: %s\n' "$signed_app_path"
    printf 'Archive signed before export: %s\n' "$archive_signed"
    printf 'Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } >"$RELEASE_DIAGNOSTICS_PATH/summary.txt"

  rm -rf "$temp_dir"
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
  if [ "$UNSIGNED_ARCHIVE" = true ]; then
    step "Archiving the unsigned release build"
  else
    step "Archiving the signed release build"
  fi
  rm -rf "$ARCHIVE_OUTPUT_PATH" "$ARCHIVE_DERIVED_DATA_PATH"

  xcodebuild_archive_args=(
    archive
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -configuration Release
    -destination "generic/platform=iOS"
    -archivePath "$ARCHIVE_OUTPUT_PATH"
    -derivedDataPath "$ARCHIVE_DERIVED_DATA_PATH"
  )
  if [ "$UNSIGNED_ARCHIVE" = false ]; then
    xcodebuild_archive_args+=("${XCODEBUILD_ARCHIVE_PROVISIONING_ARGS[@]}")
  fi
  if [ "$DISABLE_SWIFT_COMPILE_CACHE" = true ]; then
    xcodebuild_archive_args+=("${XCODEBUILD_COMPILE_CACHE_ARGS[@]}")
  fi
  if [ "$UNSIGNED_ARCHIVE" = true ]; then
    xcodebuild_archive_args+=("${XCODEBUILD_ARCHIVE_SIGNING_ARGS[@]}")
  fi

  xcodebuild "${xcodebuild_archive_args[@]}"

  ok "Archive created at $ARCHIVE_OUTPUT_PATH"
else
  ok "Skipping archive build"
fi

[ -d "$APP_BUNDLE_PATH" ] || fail "Archive is missing $APP_BUNDLE_PATH"

if [ "$UNSIGNED_ARCHIVE" = true ]; then
  step "Ad-hoc signing archived app with requested release entitlements"
  adhoc_sign_archived_app_with_release_entitlements
  ok "Archived app carries requested entitlements for export"
fi

IPA_FILE=""
if [ "$SKIP_EXPORT" = false ]; then
  step "Exporting the App Store package"
  rm -rf "$EXPORT_OUTPUT_PATH"

  xcodebuild_export_args=(
    -exportArchive
    -archivePath "$ARCHIVE_OUTPUT_PATH"
    -exportOptionsPlist "$EXPORT_OPTIONS_PATHNAME"
    -exportPath "$EXPORT_OUTPUT_PATH"
    -allowProvisioningUpdates
  )
  if [ "$HAS_APP_STORE_CONNECT_AUTH" = true ]; then
    xcodebuild_export_args+=("${XCODEBUILD_AUTH_ARGS[@]}")
  fi

  xcodebuild "${xcodebuild_export_args[@]}"

  IPA_FILE="$(find "$EXPORT_OUTPUT_PATH" -name '*.ipa' -print -quit)"
  [ -n "$IPA_FILE" ] || fail "No IPA was exported to $EXPORT_OUTPUT_PATH"
  ok "Exported IPA: $IPA_FILE"

  step "Writing signed app entitlement diagnostics"
  write_ipa_entitlement_diagnostics "$IPA_FILE"
  ok "Release entitlement diagnostics written to $RELEASE_DIAGNOSTICS_PATH"

  step "Validating signed app entitlements"
  validate_signed_ipa_entitlements "$IPA_FILE"
  ok "Signed app entitlements are valid"
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
4. Complete App Privacy answers in App Store Connect.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
