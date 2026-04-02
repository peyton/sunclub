#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cktool

token="${1:-${CKTOOL_TOKEN_TO_SAVE:-}}"
cmd=(xcrun cktool save-token --type "$CLOUDKIT_TOKEN_TYPE" --method "$CLOUDKIT_TOKEN_METHOD" --force)

if [ -n "$token" ]; then
  cmd+=("$token")
fi

"${cmd[@]}"
