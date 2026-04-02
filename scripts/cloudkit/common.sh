#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/tooling/common.sh"

setup_local_tooling_env

CLOUDKIT_CONTAINER_ID="${CLOUDKIT_CONTAINER_ID:-iCloud.app.peyton.sunclub}"
CLOUDKIT_TEAM_ID="${CLOUDKIT_TEAM_ID:-${TEAM_ID:-3VDQ4656LX}}"
CLOUDKIT_ENVIRONMENT="${CLOUDKIT_ENVIRONMENT:-development}"
CLOUDKIT_SCHEMA_FILE="${CLOUDKIT_SCHEMA_FILE:-$REPO_ROOT/.state/cloudkit/sunclub-cloudkit-schema.json}"
CLOUDKIT_TOKEN_METHOD="${CLOUDKIT_TOKEN_METHOD:-keychain}"
CLOUDKIT_TOKEN_TYPE="${CLOUDKIT_TOKEN_TYPE:-management}"

require_cktool() {
  xcrun cktool version >/dev/null
}

ensure_cloudkit_state() {
  mkdir -p "$(dirname -- "$CLOUDKIT_SCHEMA_FILE")"
}

require_schema_file() {
  if [ ! -f "$CLOUDKIT_SCHEMA_FILE" ]; then
    printf 'CloudKit schema file not found at %s\n' "$CLOUDKIT_SCHEMA_FILE" >&2
    printf '%s\n' 'Run just cloudkit-export-schema first or set CLOUDKIT_SCHEMA_FILE to an existing schema file.' >&2
    exit 2
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
