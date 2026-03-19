#!/usr/bin/env bash
#
# archive-and-upload.sh — Build, archive, and upload Sunclub to App Store Connect.
#
# Prerequisites:
#   - Xcode 16+ with valid signing identity
#   - Apple Developer account enrolled in the Apple Developer Program
#   - App created in App Store Connect (bundle ID: app.peyton.sunclub)
#   - An app-specific password stored in Keychain (see setup steps below)
#
# Usage:
#   ./scripts/appstore/archive-and-upload.sh [--skip-generate] [--skip-archive] [--dry-run]
#
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

WORKSPACE="app/Sunclub.xcworkspace"
SCHEME="Sunclub"
ARCHIVE_PATH=".build/Sunclub.xcarchive"
EXPORT_PATH=".build/export"
EXPORT_OPTIONS="scripts/appstore/ExportOptions.plist"

# Apple ID for App Store Connect authentication.
# Set via env var or fall back to this default.
APPLE_ID="${SUNCLUB_APPLE_ID:-}"
TEAM_ID="3VDQ4656LX"

# ─── Flags ───────────────────────────────────────────────────────────────────

SKIP_GENERATE=false
SKIP_ARCHIVE=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --skip-generate) SKIP_GENERATE=true ;;
    --skip-archive)  SKIP_ARCHIVE=true ;;
    --dry-run)       DRY_RUN=true ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────

step() { printf '\n\033[1;33m→ %s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$1"; exit 1; }

# ─── Preflight checks ───────────────────────────────────────────────────────

step "Preflight checks"

command -v xcodebuild >/dev/null || fail "xcodebuild not found. Install Xcode."
command -v xcrun >/dev/null      || fail "xcrun not found. Install Xcode command line tools."

if [ -z "$APPLE_ID" ]; then
  echo ""
  echo "  SUNCLUB_APPLE_ID is not set."
  echo "  Export it before running, e.g.:"
  echo ""
  echo "    export SUNCLUB_APPLE_ID=\"you@example.com\""
  echo ""
  fail "Missing SUNCLUB_APPLE_ID environment variable."
fi

# Check for app-specific password in keychain
if ! security find-generic-password -s "sunclub-asc" >/dev/null 2>&1; then
  echo ""
  echo "  No app-specific password found in Keychain under service 'sunclub-asc'."
  echo "  Generate one at https://appleid.apple.com/account/manage → App-Specific Passwords"
  echo "  Then store it:"
  echo ""
  echo "    security add-generic-password -s sunclub-asc -a \"\$SUNCLUB_APPLE_ID\" -w \"xxxx-xxxx-xxxx-xxxx\""
  echo ""
  fail "Missing app-specific password in Keychain."
fi

APP_SPECIFIC_PASSWORD=$(security find-generic-password -s "sunclub-asc" -w 2>/dev/null)
ok "Preflight passed"

# ─── Step 1: Generate project (Tuist) ───────────────────────────────────────

if [ "$SKIP_GENERATE" = false ]; then
  step "Generating Xcode project with Tuist"
  (cd app && tuist install && tuist generate --no-open)
  ok "Project generated"
else
  ok "Skipping project generation (--skip-generate)"
fi

# ─── Step 2: Bump build number ──────────────────────────────────────────────

step "Setting build number"

BUILD_NUMBER=$(date +%Y%m%d%H%M)
echo "  Build number: $BUILD_NUMBER"

# Tuist manages CURRENT_PROJECT_VERSION in Project.swift, but we can override
# at build time via xcconfig/build settings.
ok "Build number: $BUILD_NUMBER"

# ─── Step 3: Archive ────────────────────────────────────────────────────────

if [ "$SKIP_ARCHIVE" = false ]; then
  step "Archiving $SCHEME"

  rm -rf "$ARCHIVE_PATH"

  xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    -quiet

  ok "Archive created at $ARCHIVE_PATH"
else
  ok "Skipping archive (--skip-archive)"
fi

# ─── Step 4: Export IPA ─────────────────────────────────────────────────────

step "Exporting IPA"

rm -rf "$EXPORT_PATH"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_PATH" \
  -quiet

IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -print -quit)

if [ -z "$IPA_FILE" ]; then
  fail "No IPA found in $EXPORT_PATH"
fi

ok "IPA exported: $IPA_FILE"

# ─── Step 5: Validate ───────────────────────────────────────────────────────

step "Validating IPA with App Store Connect"

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Skipping validation"
else
  xcrun altool --validate-app \
    --file "$IPA_FILE" \
    --type ios \
    --apiKey "$APPLE_ID" \
    --apiIssuer "$TEAM_ID" 2>/dev/null || \
  xcrun altool --validate-app \
    --file "$IPA_FILE" \
    --type ios \
    --username "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD"

  ok "Validation passed"
fi

# ─── Step 6: Upload ─────────────────────────────────────────────────────────

step "Uploading to App Store Connect"

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would upload: $IPA_FILE"
  echo "  Run without --dry-run to upload for real."
else
  xcrun altool --upload-app \
    --file "$IPA_FILE" \
    --type ios \
    --username "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD"

  ok "Upload complete!"
fi

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Archive:  $ARCHIVE_PATH"
echo "  IPA:      $IPA_FILE"
echo "  Build #:  $BUILD_NUMBER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Go to App Store Connect → Your App → TestFlight"
echo "  2. Wait for processing (usually 5–15 minutes)"
echo "  3. Add to a test group or submit for review"
echo ""
