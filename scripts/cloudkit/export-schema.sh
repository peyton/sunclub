#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cktool
ensure_cloudkit_state

run_cktool_for_container export-schema --output-file "$CLOUDKIT_SCHEMA_FILE"
printf 'Exported CloudKit schema to %s\n' "$CLOUDKIT_SCHEMA_FILE"
