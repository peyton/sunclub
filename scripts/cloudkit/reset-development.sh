#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cktool

if [ "${CLOUDKIT_RESET_CONFIRM:-}" != "reset-development" ]; then
  printf 'Refusing to reset the CloudKit development environment without confirmation.\n' >&2
  printf 'Re-run with CLOUDKIT_RESET_CONFIRM=reset-development just cloudkit-reset-dev\n' >&2
  exit 2
fi

run_cktool_for_container reset-schema
printf 'Reset CloudKit development schema for %s.\n' "$CLOUDKIT_CONTAINER_ID"
