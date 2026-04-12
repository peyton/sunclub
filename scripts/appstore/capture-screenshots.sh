#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/tooling/common.sh"

ensure_local_state

export MISE_CONFIG_DIR="$ROOT_DIR/.config/mise"
export UV_CACHE_DIR="$ROOT_DIR/.cache/uv"
export UV_PROJECT_ENVIRONMENT="$ROOT_DIR/.venv"
export HK_CACHE_DIR="$ROOT_DIR/.cache/hk"
export HK_STATE_DIR="$ROOT_DIR/.state/hk"
export npm_config_cache="$ROOT_DIR/.cache/npm"

run_mise_exec uv run python -m scripts.appstore.capture_screenshots "$@"
