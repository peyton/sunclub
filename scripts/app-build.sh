#!/usr/bin/env bash
set -euo pipefail

# ---- Config (can be overridden via env) ----
WORKSPACE="${WORKSPACE:-Sunclub.xcworkspace}"
SCHEME="${SCHEME:-Sunclub}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"

# ---- Paths ----

BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/ci-build.XXXXXX")}"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
RESULT_BUNDLE="$BUILD_ROOT/ResultBundle.xcresult"

echo "BUILD_ROOT=$BUILD_ROOT"
echo "DERIVED_DATA=$DERIVED_DATA"
echo "RESULT_BUNDLE=$RESULT_BUNDLE"

tuist xcodebuild \
	-workspace "$WORKSPACE" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-destination "$DESTINATION" \
	-derivedDataPath "$DERIVED_DATA" \
	-resultBundlePath "$RESULT_BUNDLE" \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO \
	build

tuist share Sunclub --configuration "$CONFIGURATION" --platforms "iOS"

echo "Result bundle: $RESULT_BUNDLE"
