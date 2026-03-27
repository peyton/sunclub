#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

build_args=()
if [ -n "${CONFIGURATION:-}" ]; then
  build_args+=(--configuration "$CONFIGURATION")
fi
if [ -n "${DESTINATION:-}" ]; then
  build_args+=(--destination "$DESTINATION")
fi
if [ -n "${BUILD_ROOT:-}" ]; then
  build_args+=(--build-root "$BUILD_ROOT")
fi
if [ -n "${DERIVED_DATA:-}" ]; then
  build_args+=(--derived-data-path "$DERIVED_DATA")
fi
if [ -n "${RESULT_BUNDLE:-}" ]; then
  build_args+=(--result-bundle-path "$RESULT_BUNDLE")
fi

exec "$SCRIPT_DIR/tooling/build.sh" --skip-generate "${build_args[@]}"
