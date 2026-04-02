#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cktool
require_schema_file
require_cloudkit_team_access

run_cktool_for_container import-schema --validate --file "$CLOUDKIT_SCHEMA_FILE"
printf 'Imported CloudKit schema %s into %s (%s).\n' \
  "$CLOUDKIT_SCHEMA_FILE" \
  "$CLOUDKIT_CONTAINER_ID" \
  "$CLOUDKIT_ENVIRONMENT"
