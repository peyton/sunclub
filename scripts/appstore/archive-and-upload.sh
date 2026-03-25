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

WORKSPACE="app/Sunclub.xcworkspace"
SCHEME="Sunclub"
ARCHIVE_PATH=".build/Sunclub.xcarchive"
EXPORT_PATH=".build/export"
EXPORT_OPTIONS="scripts/appstore/ExportOptions.plist"
DERIVED_DATA=".DerivedData/archive"
VALIDATOR="scripts/appstore/validate_metadata.py"
TEAM_ID="3VDQ4656LX"

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

[ -f "$VALIDATOR" ] || fail "Missing metadata validator: $VALIDATOR"
[ -f "$EXPORT_OPTIONS" ] || fail "Missing export options: $EXPORT_OPTIONS"
command -v python3 >/dev/null || fail "python3 is required."
command -v xcodebuild >/dev/null || fail "xcodebuild is required."
command -v xcrun >/dev/null || fail "xcrun is required."

step "Validating App Store metadata"
python3 "$VALIDATOR" "scripts/appstore/metadata.json"
ok "Submission manifest is valid"

if [ "$SKIP_GENERATE" = false ]; then
	step "Generating the Tuist workspace"
	(cd app && tuist install && tuist generate --no-open)
	ok "Workspace generated"
else
	ok "Skipping workspace generation"
fi

if [ "$SKIP_ARCHIVE" = false ]; then
	step "Archiving the signed release build"
	rm -rf "$ARCHIVE_PATH" "$DERIVED_DATA"

	xcodebuild archive \
		-workspace "$WORKSPACE" \
		-scheme "$SCHEME" \
		-configuration Release \
		-destination "generic/platform=iOS" \
		-archivePath "$ARCHIVE_PATH" \
		-derivedDataPath "$DERIVED_DATA" \
		DEVELOPMENT_TEAM="$TEAM_ID" \
		CODE_SIGN_STYLE=Automatic

	ok "Archive created at $ARCHIVE_PATH"
else
	ok "Skipping archive build"
fi

APP_BUNDLE="$ARCHIVE_PATH/Products/Applications/Sunclub.app"
[ -d "$APP_BUNDLE" ] || fail "Archive is missing $APP_BUNDLE"

step "Verifying model packaging"
if find "$APP_BUNDLE" \( -name "config.json" -o -name "*.mlpackage" -o -name "*.bin" \) | grep -q .; then
	fail "The archived app bundle still contains FastVLM model payload files."
fi

if ! find "$ARCHIVE_PATH" \( -name "*.assetpack" -o -path "*OnDemandResources*" \) | grep -q .; then
	fail "No On-Demand Resource asset pack was found in the archive."
fi

ok "Archive keeps FastVLM out of the .app bundle and retains an ODR asset pack"

if [ "$SKIP_EXPORT" = false ]; then
	step "Exporting the App Store package"
	rm -rf "$EXPORT_PATH"

	xcodebuild -exportArchive \
		-archivePath "$ARCHIVE_PATH" \
		-exportOptionsPlist "$EXPORT_OPTIONS" \
		-exportPath "$EXPORT_PATH"

	IPA_FILE="$(find "$EXPORT_PATH" -name '*.ipa' -print -quit)"
	[ -n "$IPA_FILE" ] || fail "No IPA was exported to $EXPORT_PATH"
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
