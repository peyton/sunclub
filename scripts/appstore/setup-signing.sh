#!/usr/bin/env bash
#
# setup-signing.sh — One-time setup for App Store submission credentials.
#
# This script guides you through storing the credentials needed for
# archive-and-upload.sh and create-app-store-listing.sh.
#
set -euo pipefail

step() { printf '\n\033[1;33m→ %s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Sunclub — App Store Signing Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Step 1: Apple ID ───────────────────────────────────────────────────────

step "Apple ID for App Store Connect"
echo "  This is the email you use to sign into App Store Connect."
read -rp "  Apple ID: " APPLE_ID

if [ -z "$APPLE_ID" ]; then
  echo "  Skipped."
else
  echo ""
  echo "  Add this to your shell profile (~/.zshrc or ~/.bashrc):"
  echo ""
  echo "    export SUNCLUB_APPLE_ID=\"$APPLE_ID\""
  echo ""
fi

# ─── Step 2: App-specific password ──────────────────────────────────────────

step "App-specific password"
echo "  Generate one at: https://appleid.apple.com/account/manage"
echo "  Click 'Sign-In and Security' → 'App-Specific Passwords' → '+'"
echo "  Name it 'sunclub-asc'"
echo ""
read -rsp "  Paste your app-specific password (input hidden): " ASP
echo ""

if [ -z "$ASP" ]; then
  echo "  Skipped."
else
  security add-generic-password -s "sunclub-asc" -a "$APPLE_ID" -w "$ASP" -U
  ok "Password stored in Keychain under service 'sunclub-asc'"
fi

# ─── Step 3: ASC API Key (optional, for metadata script) ────────────────────

step "App Store Connect API Key (optional — for metadata automation)"
echo "  Go to: https://appstoreconnect.apple.com/access/integrations/api"
echo "  Create a key with 'App Manager' role."
echo "  Download the .p8 file."
echo ""
read -rp "  API Key ID (or press Enter to skip): " ASC_KEY_ID

if [ -n "$ASC_KEY_ID" ]; then
  read -rp "  Issuer ID: " ASC_ISSUER_ID
  read -rp "  Path to .p8 key file: " ASC_KEY_FILE

  mkdir -p "$HOME/.appstoreconnect"
  if [ -f "$ASC_KEY_FILE" ] && [ "$ASC_KEY_FILE" != "$HOME/.appstoreconnect/AuthKey_$ASC_KEY_ID.p8" ]; then
    cp "$ASC_KEY_FILE" "$HOME/.appstoreconnect/AuthKey_$ASC_KEY_ID.p8"
    ok "Key copied to ~/.appstoreconnect/"
  fi

  echo ""
  echo "  Add these to your shell profile:"
  echo ""
  echo "    export ASC_KEY_ID=\"$ASC_KEY_ID\""
  echo "    export ASC_ISSUER_ID=\"$ASC_ISSUER_ID\""
  echo "    export ASC_KEY_FILE=\"\$HOME/.appstoreconnect/AuthKey_$ASC_KEY_ID.p8\""
  echo ""
else
  echo "  Skipped. You can set this up later if you want metadata automation."
fi

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup complete! Next steps:"
echo ""
echo "  1. Source your shell profile:  source ~/.zshrc"
echo "  2. Bump version:              ./scripts/appstore/bump-version.sh 1.0"
echo "  3. Archive & upload:          ./scripts/appstore/archive-and-upload.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
