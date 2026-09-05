#!/usr/bin/env bash
set -euo pipefail

case "${1:-${SUNCLUB_FLAVOR:-dev}}" in
dev) export SUNCLUB_FLAVOR=dev SUNCLUB_APS_ENVIRONMENT=development ;;
prod) export SUNCLUB_FLAVOR=prod SUNCLUB_APS_ENVIRONMENT=production ;;
*)
  printf 'Usage: ci_build.sh [dev|prod]\n' >&2
  exit 2
  ;;
esac
# The requested flavor wins over a previously prepared shell environment.
unset APP_SCHEME APP_IDENTIFIER RUN_APP_PATH
exec bash "$(dirname -- "$0")/build.sh" --configuration Release --destination 'generic/platform=iOS'
