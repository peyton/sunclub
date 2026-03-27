#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env
"$TOOLING_DIR/bootstrap.sh"
prepare_ci_workspace xcode-cloud
generate_workspace
