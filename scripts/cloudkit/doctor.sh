#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

open_portal=0

while [ $# -gt 0 ]; do
  case "$1" in
  --open-portal)
    open_portal=1
    shift
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

require_cktool
ensure_cloudkit_state
require_cloudkit_team_access

printf 'Validated CloudKit management token for team %s via cktool get-teams.\n' "$CLOUDKIT_TEAM_ID"

schema_probe="$REPO_ROOT/.state/cloudkit/doctor-schema-probe.json"
schema_probe_log="$REPO_ROOT/.state/cloudkit/doctor-schema-probe.log"
provisioning_log="$REPO_ROOT/.state/cloudkit/doctor-provisioning.log"

rm -f "$schema_probe" "$schema_probe_log" "$provisioning_log"

if run_cktool_for_container export-schema --output-file "$schema_probe" >"$schema_probe_log" 2>&1; then
  printf 'CloudKit management API can export schema for %s (%s).\n' \
    "$CLOUDKIT_CONTAINER_ID" \
    "$CLOUDKIT_ENVIRONMENT"
  printf 'Schema probe saved to %s\n' "$schema_probe"
  exit 0
fi

printf 'cktool export-schema could not access %s (%s).\n' \
  "$CLOUDKIT_CONTAINER_ID" \
  "$CLOUDKIT_ENVIRONMENT"
printf 'cktool output:\n'
cat "$schema_probe_log"

printf 'Running a signed build with automatic provisioning updates for team %s.\n' "$CLOUDKIT_TEAM_ID"

if ! run_cloudkit_signed_build "$CLOUDKIT_PROVISIONING_DERIVED_DATA" >"$provisioning_log" 2>&1; then
  printf 'xcodebuild failed while checking CloudKit provisioning.\n' >&2
  printf 'Provisioning log: %s\n' "$provisioning_log" >&2
  tail -n 40 "$provisioning_log" >&2 || true
  exit 1
fi

printf 'Provisioning build log: %s\n' "$provisioning_log"

xcent_path="$(find_signed_app_xcent "$CLOUDKIT_PROVISIONING_DERIVED_DATA")"
if [ -z "$xcent_path" ]; then
  printf 'Unable to locate the signed app entitlements file under %s.\n' "$CLOUDKIT_PROVISIONING_DERIVED_DATA" >&2
  exit 1
fi

entitlements_summary="$(read_plist_summary "$xcent_path")"
printf 'Signed entitlements file: %s\n' "$xcent_path"
printf '%s\n' "$entitlements_summary"

if signed_entitlements_have_cloudkit "$entitlements_summary"; then
  printf '%s\n' 'The signed app now includes CloudKit entitlements, so the App ID and container assignment exist on the Apple side.'
  printf '%s\n' 'The remaining cktool authorization-failed error is not caused by a missing management token or missing App ID capability.'
  exit 1
fi

print_cloudkit_setup_instructions

if [ "$open_portal" -eq 1 ]; then
  printf '%s\n' 'Opening the Apple setup pages in your browser.'
  open_cloudkit_setup_pages
fi

exit 2
