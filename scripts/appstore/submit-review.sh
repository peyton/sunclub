#!/usr/bin/env bash
#
# Capture App Store screenshots, upload the release build to App Store Connect,
# and submit the prepared app version for App Review.
#
# Final submission requires either:
#   SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1 bash scripts/appstore/submit-review.sh --submit
# or:
#   bash scripts/appstore/submit-review.sh --submit --confirm-submit
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/tooling/common.sh"

: "${SUNCLUB_FLAVOR:=prod}"
: "${SUNCLUB_APS_ENVIRONMENT:=production}"
setup_local_tooling_env

SUBMIT=false
CONFIRM_SUBMIT=false
SKIP_SCREENSHOTS=false
SKIP_ARCHIVE_UPLOAD=false
PYTHON_ARGS=()

for arg in "$@"; do
  case "$arg" in
  --dry-run)
    PYTHON_ARGS+=(--dry-run)
    ;;
  --submit)
    SUBMIT=true
    PYTHON_ARGS+=(--submit)
    ;;
  --confirm-submit)
    CONFIRM_SUBMIT=true
    PYTHON_ARGS+=(--confirm-submit)
    ;;
  --skip-screenshots)
    SKIP_SCREENSHOTS=true
    ;;
  --skip-archive-upload)
    SKIP_ARCHIVE_UPLOAD=true
    ;;
  *)
    PYTHON_ARGS+=("$arg")
    ;;
  esac
done

if [ "$SUBMIT" = false ]; then
  run_repo_python_module scripts.appstore.submit_review "${PYTHON_ARGS[@]}"
  exit 0
fi

if [ "$CONFIRM_SUBMIT" = false ] && [ "${SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT:-0}" != "1" ]; then
  printf 'Final App Review submission requires --confirm-submit or SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1.\n' >&2
  exit 2
fi

run_repo_python_module scripts.appstore.validate_metadata scripts/appstore/metadata.json

if [ "$SKIP_SCREENSHOTS" = false ]; then
  bash scripts/appstore/capture-screenshots.sh
fi

if [ "$SKIP_ARCHIVE_UPLOAD" = false ]; then
  bash scripts/appstore/archive-and-upload.sh --upload-testflight
fi

run_repo_python_module scripts.appstore.submit_review "${PYTHON_ARGS[@]}"
