#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env
run_mise_exec tuist inspect build --derived-data-path "$CI_DERIVED_DATA_PATH" --path "$REPO_ROOT/app"
