#!/usr/bin/env bash
#
# Capture App Store screenshots, upload the release build to App Store Connect,
# and submit the prepared app version for App Review.
#
# Final non-interactive submission requires:
#   SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1
#   SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED=1
#
# Local interactive submission asks for an exact checkpoint phrase after
# strict validation and screenshot capture.
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/tooling/common.sh"
source_appstore_review_env

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

run_repo_python_module scripts.appstore.validate_metadata scripts/appstore/metadata.json

if [ "$SKIP_SCREENSHOTS" = false ]; then
  bash scripts/appstore/capture-screenshots.sh
fi

run_repo_python_module scripts.appstore.review_package --checkpoint

if [ "${SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED:-0}" != "1" ]; then
  expected="submit Sunclub $SUNCLUB_MARKETING_VERSION ($SUNCLUB_BUILD_NUMBER) to App Review"
  printf '\nReview .build/appstore-review-checkpoint/summary.md, then type this exact phrase to continue:\n%s\n> ' "$expected"
  if ! IFS= read -r actual; then
    printf 'Could not read checkpoint confirmation.\n' >&2
    exit 2
  fi
  if [ "$actual" != "$expected" ]; then
    printf 'Checkpoint confirmation did not match. Submission aborted before upload or App Store Connect mutation.\n' >&2
    exit 2
  fi
  export SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED=1
  export SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1
fi

if [ "$CONFIRM_SUBMIT" = false ] && [ "${SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT:-0}" != "1" ]; then
  printf 'Final App Review submission requires --confirm-submit or SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1.\n' >&2
  exit 2
fi

if [ "$SKIP_ARCHIVE_UPLOAD" = false ]; then
  bash scripts/appstore/archive-and-upload.sh --upload-testflight
fi

run_repo_python_module scripts.appstore.submit_review "${PYTHON_ARGS[@]}"
