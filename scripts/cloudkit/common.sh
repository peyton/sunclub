#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/tooling/common.sh"

: "${SUNCLUB_FLAVOR:=prod}"
setup_local_tooling_env

CLOUDKIT_CONTAINER_ID="${CLOUDKIT_CONTAINER_ID:-iCloud.app.peyton.sunclub}"
CLOUDKIT_TEAM_ID="${CLOUDKIT_TEAM_ID:-${TEAM_ID:-3VDQ4656LX}}"
CLOUDKIT_ENVIRONMENT="${CLOUDKIT_ENVIRONMENT:-development}"
CLOUDKIT_SCHEMA_FILE="${CLOUDKIT_SCHEMA_FILE:-$REPO_ROOT/.state/cloudkit/sunclub-cloudkit-schema.json}"
CLOUDKIT_TOKEN_METHOD="${CLOUDKIT_TOKEN_METHOD:-keychain}"
CLOUDKIT_TOKEN_TYPE="${CLOUDKIT_TOKEN_TYPE:-management}"
CLOUDKIT_PROVISIONING_DERIVED_DATA="${CLOUDKIT_PROVISIONING_DERIVED_DATA:-$REPO_ROOT/.DerivedData/cloudkit-provisioning}"
CLOUDKIT_CREATE_CONTAINER_HELP_URL="${CLOUDKIT_CREATE_CONTAINER_HELP_URL:-https://developer.apple.com/help/account/identifiers/create-an-icloud-container/}"
CLOUDKIT_ENABLE_ICLOUD_HELP_URL="${CLOUDKIT_ENABLE_ICLOUD_HELP_URL:-https://developer.apple.com/help/account/identifiers/enable-app-capabilities/}"
CLOUDKIT_AUTOMATIC_SIGNING_HELP_URL="${CLOUDKIT_AUTOMATIC_SIGNING_HELP_URL:-https://developer.apple.com/help/account/access/automatic-signing-controls/}"
CLOUDKIT_IDENTIFIERS_URL="${CLOUDKIT_IDENTIFIERS_URL:-https://developer.apple.com/account/resources/identifiers/list}"

require_cktool() {
  xcrun cktool version >/dev/null
}

ensure_cloudkit_state() {
  mkdir -p "$(dirname -- "$CLOUDKIT_SCHEMA_FILE")"
}

require_consistent_team_ids() {
  if [ "${TEAM_ID:-$CLOUDKIT_TEAM_ID}" != "$CLOUDKIT_TEAM_ID" ]; then
    printf 'TEAM_ID (%s) must match CLOUDKIT_TEAM_ID (%s).\n' "${TEAM_ID:-}" "$CLOUDKIT_TEAM_ID" >&2
    printf '%s\n' 'Update scripts/tooling/sunclub.env or your shell overrides so the app signing team matches the CloudKit team.' >&2
    exit 2
  fi
}

require_schema_file() {
  if [ ! -f "$CLOUDKIT_SCHEMA_FILE" ]; then
    printf 'CloudKit schema file not found at %s\n' "$CLOUDKIT_SCHEMA_FILE" >&2
    printf '%s\n' 'Run just cloudkit-export-schema first or set CLOUDKIT_SCHEMA_FILE to an existing schema file.' >&2
    exit 2
  fi
}

run_cktool_management() {
  local subcommand="$1"
  shift

  local -a cmd=(xcrun cktool "$subcommand")
  if [ -n "${CKTOOL_TOKEN:-}" ]; then
    cmd+=(--token "$CKTOOL_TOKEN")
  fi

  cmd+=("$@")
  "${cmd[@]}"
}

require_cloudkit_team_access() {
  require_consistent_team_ids

  local teams_output
  if ! teams_output="$(run_cktool_management get-teams 2>&1)"; then
    printf 'Unable to query CloudKit teams with the saved token.\n' >&2
    printf '%s\n' "$teams_output" >&2
    printf '%s\n' 'Save a CloudKit management token with just cloudkit-save-token and try again.' >&2
    exit 1
  fi

  if ! printf '%s\n' "$teams_output" | grep -Fq "$CLOUDKIT_TEAM_ID:"; then
    printf 'Configured CloudKit team %s is not visible to the saved management token.\n' "$CLOUDKIT_TEAM_ID" >&2
    printf '%s\n' "$teams_output" >&2
    exit 1
  fi
}

run_cktool_for_container() {
  local subcommand="$1"
  shift

  local -a cmd=(xcrun cktool "$subcommand")
  if [ -n "${CKTOOL_TOKEN:-}" ]; then
    cmd+=(--token "$CKTOOL_TOKEN")
  fi

  cmd+=(--team-id "$CLOUDKIT_TEAM_ID" --container-id "$CLOUDKIT_CONTAINER_ID")

  if [ "$subcommand" != "reset-schema" ]; then
    cmd+=(--environment "$CLOUDKIT_ENVIRONMENT")
  fi

  cmd+=("$@")
  "${cmd[@]}"
}

run_cloudkit_signed_build() {
  local derived_data_path="${1:-$CLOUDKIT_PROVISIONING_DERIVED_DATA}"

  ensure_workspace_generated
  rm -rf "$derived_data_path"
  mkdir -p "$(dirname -- "$derived_data_path")"

  if has_app_store_connect_auth; then
    xcodebuild \
      -workspace "$REPO_ROOT/$APP_WORKSPACE" \
      -scheme "$RELEASE_APP_SCHEME" \
      -configuration Debug \
      -destination "generic/platform=iOS" \
      -derivedDataPath "$derived_data_path" \
      -allowProvisioningUpdates \
      -authenticationKeyPath "$ASC_KEY_FILE" \
      -authenticationKeyID "$ASC_KEY_ID" \
      -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
      DEVELOPMENT_TEAM="$CLOUDKIT_TEAM_ID" \
      build
  else
    xcodebuild \
      -workspace "$REPO_ROOT/$APP_WORKSPACE" \
      -scheme "$RELEASE_APP_SCHEME" \
      -configuration Debug \
      -destination "generic/platform=iOS" \
      -derivedDataPath "$derived_data_path" \
      -allowProvisioningUpdates \
      DEVELOPMENT_TEAM="$CLOUDKIT_TEAM_ID" \
      build
  fi
}

find_signed_app_xcent() {
  local derived_data_path="$1"

  find "$derived_data_path" \
    -path '*Sunclub.build/Debug-iphoneos/Sunclub.build/Sunclub.app.xcent' \
    -print \
    -quit
}

read_plist_summary() {
  local plist_path="$1"
  plutil -p "$plist_path"
}

signed_entitlements_have_cloudkit() {
  local summary="$1"

  if ! printf '%s\n' "$summary" | grep -Fq 'com.apple.developer.icloud-container-identifiers'; then
    return 1
  fi

  if ! printf '%s\n' "$summary" | grep -Fq "$CLOUDKIT_CONTAINER_ID"; then
    return 1
  fi

  if ! printf '%s\n' "$summary" | grep -Fq 'com.apple.developer.icloud-services'; then
    return 1
  fi

  printf '%s\n' "$summary" | grep -Fq 'CloudKit'
}

print_cloudkit_setup_instructions() {
  cat <<EOF
CloudKit is not configured for App ID $RELEASE_APP_IDENTIFIER on team $CLOUDKIT_TEAM_ID.

Required Apple-side setup:
1. Create the iCloud container $CLOUDKIT_CONTAINER_ID.
2. Enable the iCloud capability on App ID $RELEASE_APP_IDENTIFIER and assign $CLOUDKIT_CONTAINER_ID.
3. If Xcode automatic signing should be allowed to make those changes, confirm Automatic Signing Controls are not blocking App ID updates for your role.

Official Apple references:
- Create an iCloud container: $CLOUDKIT_CREATE_CONTAINER_HELP_URL
- Enable iCloud for an App ID: $CLOUDKIT_ENABLE_ICLOUD_HELP_URL
- Automatic Signing Controls: $CLOUDKIT_AUTOMATIC_SIGNING_HELP_URL
- Certificates, IDs & Profiles: $CLOUDKIT_IDENTIFIERS_URL

Apple's docs say creating an iCloud container requires the Account Holder or Admin role.
EOF
}

open_cloudkit_setup_pages() {
  if ! command -v open >/dev/null 2>&1; then
    printf '%s\n' 'The macOS open command is unavailable; open the URLs above manually.' >&2
    return 0
  fi

  open "$CLOUDKIT_IDENTIFIERS_URL"
  open "$CLOUDKIT_CREATE_CONTAINER_HELP_URL"
  open "$CLOUDKIT_ENABLE_ICLOUD_HELP_URL"
  open "$CLOUDKIT_AUTOMATIC_SIGNING_HELP_URL"
}
