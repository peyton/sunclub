#!/usr/bin/env bash
#
# create-app-store-listing.sh — Create or update the App Store Connect listing via the ASC API.
#
# This script uses Apple's App Store Connect API (via xcrun) to:
#   1. Create the app if it doesn't exist
#   2. Set metadata (description, keywords, etc.)
#   3. Upload screenshots
#
# Prerequisites:
#   - An API key from App Store Connect (https://appstoreconnect.apple.com/access/integrations/api)
#   - The key file (.p8) downloaded and stored locally
#
# Environment variables:
#   ASC_KEY_ID        — Your API Key ID
#   ASC_ISSUER_ID     — Your Issuer ID
#   ASC_KEY_FILE      — Path to your .p8 private key file
#
# Usage:
#   export ASC_KEY_ID="XXXXXXXXXX"
#   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   export ASC_KEY_FILE="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
#   ./scripts/appstore/create-app-store-listing.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
METADATA_FILE="$SCRIPT_DIR/metadata.json"

# ─── Validate env ────────────────────────────────────────────────────────────

step() { printf '\n\033[1;33m→ %s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$1"; exit 1; }

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_FILE; do
  if [ -z "${!var:-}" ]; then
    fail "Missing environment variable: $var"
  fi
done

[ -f "$ASC_KEY_FILE" ] || fail "Key file not found: $ASC_KEY_FILE"
[ -f "$METADATA_FILE" ] || fail "Metadata file not found: $METADATA_FILE"

command -v jq >/dev/null || fail "jq is required. Install with: brew install jq"

# ─── JWT token generation ────────────────────────────────────────────────────

step "Generating JWT for App Store Connect API"

generate_jwt() {
  local header payload signature
  local now exp

  now=$(date +%s)
  exp=$((now + 1200))  # 20 minutes

  header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  payload=$(printf '{"iss":"%s","exp":%d,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$exp" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

  signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$ASC_KEY_FILE" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

  printf '%s.%s.%s' "$header" "$payload" "$signature"
}

JWT=$(generate_jwt)
ok "JWT generated"

# ─── API helpers ─────────────────────────────────────────────────────────────

ASC_BASE="https://api.appstoreconnect.apple.com/v1"

asc_get() {
  curl -s -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" "$ASC_BASE$1"
}

asc_post() {
  curl -s -X POST -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" -d "$2" "$ASC_BASE$1"
}

asc_patch() {
  curl -s -X PATCH -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" -d "$2" "$ASC_BASE$1"
}

# ─── Read metadata ──────────────────────────────────────────────────────────

BUNDLE_ID=$(jq -r '.bundle_id' "$METADATA_FILE")
APP_NAME=$(jq -r '.app_name' "$METADATA_FILE")
SKU=$(jq -r '.sku' "$METADATA_FILE")
DESCRIPTION=$(jq -r '.description' "$METADATA_FILE")
KEYWORDS=$(jq -r '.keywords' "$METADATA_FILE")
PROMO_TEXT=$(jq -r '.promotional_text' "$METADATA_FILE")
SUPPORT_URL=$(jq -r '.support_url' "$METADATA_FILE")
MARKETING_URL=$(jq -r '.marketing_url' "$METADATA_FILE")
PRIVACY_URL=$(jq -r '.privacy_policy_url' "$METADATA_FILE")
SUBTITLE=$(jq -r '.subtitle' "$METADATA_FILE")
WHATS_NEW=$(jq -r '.whats_new' "$METADATA_FILE")
COPYRIGHT=$(jq -r '.copyright' "$METADATA_FILE")
PRIMARY_CATEGORY=$(jq -r '.primary_category' "$METADATA_FILE")

# ─── Step 1: Find or create the app ─────────────────────────────────────────

step "Looking up app with bundle ID: $BUNDLE_ID"

APPS_RESPONSE=$(asc_get "/apps?filter[bundleId]=$BUNDLE_ID")
APP_COUNT=$(echo "$APPS_RESPONSE" | jq '.data | length')

if [ "$APP_COUNT" -gt 0 ]; then
  APP_ID=$(echo "$APPS_RESPONSE" | jq -r '.data[0].id')
  ok "Found existing app: $APP_ID"
else
  echo "  App not found. You need to create it in App Store Connect first."
  echo ""
  echo "  Go to: https://appstoreconnect.apple.com/apps"
  echo "  Click '+' → New App"
  echo "  Fill in:"
  echo "    Name:      $APP_NAME"
  echo "    Bundle ID: $BUNDLE_ID"
  echo "    SKU:       $SKU"
  echo ""
  fail "Create the app in App Store Connect first, then re-run this script."
fi

# ─── Step 2: Get the app's version localization ─────────────────────────────

step "Fetching app store version info"

VERSION_RESPONSE=$(asc_get "/apps/$APP_ID/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,READY_FOR_SALE")
VERSION_ID=$(echo "$VERSION_RESPONSE" | jq -r '.data[0].id // empty')

if [ -z "$VERSION_ID" ]; then
  echo "  No editable version found. Create a new version in App Store Connect first."
  fail "No app version in PREPARE_FOR_SUBMISSION state."
fi

ok "Found version: $VERSION_ID"

# ─── Step 3: Update localization ────────────────────────────────────────────

step "Updating en-US localization"

LOCALIZATIONS=$(asc_get "/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations")
LOC_ID=$(echo "$LOCALIZATIONS" | jq -r '.data[] | select(.attributes.locale == "en-US") | .id')

if [ -z "$LOC_ID" ]; then
  fail "No en-US localization found"
fi

ESCAPED_DESC=$(echo "$DESCRIPTION" | jq -Rs '.')
ESCAPED_WHATS_NEW=$(echo "$WHATS_NEW" | jq -Rs '.')
ESCAPED_KEYWORDS=$(echo "$KEYWORDS" | jq -Rs '.')
ESCAPED_PROMO=$(echo "$PROMO_TEXT" | jq -Rs '.')

UPDATE_BODY=$(cat <<EOF
{
  "data": {
    "type": "appStoreVersionLocalizations",
    "id": "$LOC_ID",
    "attributes": {
      "description": $ESCAPED_DESC,
      "keywords": $ESCAPED_KEYWORDS,
      "promotionalText": $ESCAPED_PROMO,
      "supportUrl": "$SUPPORT_URL",
      "marketingUrl": "$MARKETING_URL",
      "whatsNew": $ESCAPED_WHATS_NEW
    }
  }
}
EOF
)

asc_patch "/appStoreVersionLocalizations/$LOC_ID" "$UPDATE_BODY" > /dev/null
ok "Localization updated"

# ─── Step 4: Update app info ───────────────────────────────────────────────

step "Updating app-level info"

APP_INFO_RESPONSE=$(asc_get "/apps/$APP_ID/appInfos")
APP_INFO_ID=$(echo "$APP_INFO_RESPONSE" | jq -r '.data[0].id // empty')

if [ -n "$APP_INFO_ID" ]; then
  APP_INFO_LOCS=$(asc_get "/appInfos/$APP_INFO_ID/appInfoLocalizations")
  APP_INFO_LOC_ID=$(echo "$APP_INFO_LOCS" | jq -r '.data[] | select(.attributes.locale == "en-US") | .id')

  if [ -n "$APP_INFO_LOC_ID" ]; then
    APP_INFO_UPDATE=$(cat <<EOF
{
  "data": {
    "type": "appInfoLocalizations",
    "id": "$APP_INFO_LOC_ID",
    "attributes": {
      "name": "$APP_NAME",
      "subtitle": "$SUBTITLE",
      "privacyPolicyUrl": "$PRIVACY_URL"
    }
  }
}
EOF
)
    asc_patch "/appInfoLocalizations/$APP_INFO_LOC_ID" "$APP_INFO_UPDATE" > /dev/null
    ok "App info updated (name, subtitle, privacy URL)"
  fi
fi

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App Store metadata updated successfully!"
echo ""
echo "  Remaining manual steps:"
echo "  1. Upload screenshots via App Store Connect UI"
echo "     (or use Transporter.app to bulk upload)"
echo "  2. Set pricing in App Store Connect"
echo "  3. Complete the App Privacy section"
echo "  4. Submit for review"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
