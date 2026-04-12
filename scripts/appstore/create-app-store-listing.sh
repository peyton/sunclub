#!/usr/bin/env bash
#
# Patch the App Store Connect fields that map cleanly to the validated
# metadata manifest. This script does not create the app, upload screenshots,
# or fill manual compliance questionnaires.
#
# Usage:
#   export ASC_KEY_ID="XXXXXXXXXX"
#   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   export ASC_KEY_FILE="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
#   ./scripts/appstore/create-app-store-listing.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/tooling/common.sh"

setup_local_tooling_env

METADATA_FILE="$SCRIPT_DIR/metadata.json"

step() { printf '\n\033[1;33m→ %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
fail() {
  printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2
  exit 1
}

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_FILE; do
  [ -n "${!var:-}" ] || fail "Missing environment variable: $var"
done

[ -f "$ASC_KEY_FILE" ] || fail "Key file not found: $ASC_KEY_FILE"
[ -f "$METADATA_FILE" ] || fail "Metadata file not found: $METADATA_FILE"

command -v jq >/dev/null || fail "jq is required. Install with: brew install jq"

step "Validating metadata manifest"
run_repo_python_module scripts.appstore.validate_metadata "$METADATA_FILE"
ok "Metadata manifest is valid"

step "Generating App Store Connect JWT"

generate_jwt() {
  local header payload signature now expires
  now=$(date +%s)
  expires=$((now + 1200))

  header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  payload=$(printf '{"iss":"%s","exp":%d,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$expires" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$ASC_KEY_FILE" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

  printf '%s.%s.%s' "$header" "$payload" "$signature"
}

JWT="$(generate_jwt)"
ASC_BASE="https://api.appstoreconnect.apple.com/v1"

asc_get() {
  curl -sf \
    -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/json" \
    "$ASC_BASE$1"
}

asc_patch() {
  curl -sf \
    -X PATCH \
    -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/json" \
    -d "$2" \
    "$ASC_BASE$1"
}

APP_NAME="$(jq -r '.app.name' "$METADATA_FILE")"
SUBTITLE="$(jq -r '.app.subtitle' "$METADATA_FILE")"
BUNDLE_ID="$(jq -r '.app.bundle_id' "$METADATA_FILE")"
PRIMARY_LOCALE="$(jq -r '.app.primary_locale' "$METADATA_FILE")"
DESCRIPTION="$(jq -r --arg locale "$PRIMARY_LOCALE" '.localizations[$locale].description' "$METADATA_FILE")"
PROMOTIONAL_TEXT="$(jq -r --arg locale "$PRIMARY_LOCALE" '.localizations[$locale].promotional_text' "$METADATA_FILE")"
WHATS_NEW="$(jq -r --arg locale "$PRIMARY_LOCALE" '.localizations[$locale].whats_new' "$METADATA_FILE")"
KEYWORDS="$(jq -r --arg locale "$PRIMARY_LOCALE" '.localizations[$locale].keywords | join(",")' "$METADATA_FILE")"
SUPPORT_URL="$(jq -r '.urls.support.value' "$METADATA_FILE")"
MARKETING_URL="$(jq -r '.urls.marketing.value' "$METADATA_FILE")"
PRIVACY_URL="$(jq -r '.urls.privacy_policy.value' "$METADATA_FILE")"

step "Looking up the existing App Store Connect app"
APP_ID="$(asc_get "/apps?filter[bundleId]=$BUNDLE_ID" | jq -r '.data[0].id // empty')"
[ -n "$APP_ID" ] || fail "No App Store Connect app exists for bundle ID $BUNDLE_ID."
ok "Found app: $APP_ID"

step "Finding the editable App Store version"
VERSION_ID="$(
  asc_get "/apps/$APP_ID/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,READY_FOR_SALE" |
    jq -r '.data[0].id // empty'
)"
[ -n "$VERSION_ID" ] || fail "No editable App Store version found. Create a version in App Store Connect first."
ok "Found version: $VERSION_ID"

step "Updating version localization fields"
LOCALIZATION_ID="$(
  asc_get "/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations" |
    jq -r --arg locale "$PRIMARY_LOCALE" '.data[] | select(.attributes.locale == $locale) | .id'
)"
[ -n "$LOCALIZATION_ID" ] || fail "No version localization exists for $PRIMARY_LOCALE."

ESCAPED_DESCRIPTION="$(printf '%s' "$DESCRIPTION" | jq -Rs '.')"
ESCAPED_PROMO="$(printf '%s' "$PROMOTIONAL_TEXT" | jq -Rs '.')"
ESCAPED_WHATS_NEW="$(printf '%s' "$WHATS_NEW" | jq -Rs '.')"
ESCAPED_KEYWORDS="$(printf '%s' "$KEYWORDS" | jq -Rs '.')"

VERSION_PAYLOAD="$(
  cat <<EOF
{
  "data": {
    "type": "appStoreVersionLocalizations",
    "id": "$LOCALIZATION_ID",
    "attributes": {
      "description": $ESCAPED_DESCRIPTION,
      "keywords": $ESCAPED_KEYWORDS,
      "promotionalText": $ESCAPED_PROMO,
      "supportUrl": "$SUPPORT_URL",
      "marketingUrl": "$MARKETING_URL",
      "whatsNew": $ESCAPED_WHATS_NEW
    }
  }
}
EOF
)"

asc_patch "/appStoreVersionLocalizations/$LOCALIZATION_ID" "$VERSION_PAYLOAD" >/dev/null
ok "Version localization updated"

step "Updating app info localization fields"
APP_INFO_ID="$(asc_get "/apps/$APP_ID/appInfos" | jq -r '.data[0].id // empty')"
[ -n "$APP_INFO_ID" ] || fail "No app info record found for app $APP_ID."

APP_INFO_LOCALIZATION_ID="$(
  asc_get "/appInfos/$APP_INFO_ID/appInfoLocalizations" |
    jq -r --arg locale "$PRIMARY_LOCALE" '.data[] | select(.attributes.locale == $locale) | .id'
)"
[ -n "$APP_INFO_LOCALIZATION_ID" ] || fail "No app info localization exists for $PRIMARY_LOCALE."

APP_INFO_PAYLOAD="$(
  cat <<EOF
{
  "data": {
    "type": "appInfoLocalizations",
    "id": "$APP_INFO_LOCALIZATION_ID",
    "attributes": {
      "name": "$APP_NAME",
      "subtitle": "$SUBTITLE",
      "privacyPolicyUrl": "$PRIVACY_URL"
    }
  }
}
EOF
)"

asc_patch "/appInfoLocalizations/$APP_INFO_LOCALIZATION_ID" "$APP_INFO_PAYLOAD" >/dev/null
ok "App info localization updated"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Patched the App Store Connect fields supported by this script.

Still manual in App Store Connect:
1. Upload screenshots from the manifest-defined capture set.
2. Enter App Review contact details and review notes.
3. Complete App Privacy answers.
4. Set pricing and availability if they differ from the current app record.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
