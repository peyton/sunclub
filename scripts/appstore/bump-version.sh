#!/usr/bin/env bash
#
# bump-version.sh — Deprecated wrapper for release-tag.sh.
#
# Usage:
#   ./scripts/appstore/bump-version.sh 1.2.3
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"

printf '%s\n' 'bump-version.sh is deprecated; tagging now drives release versions.'
exec "$ROOT_DIR/scripts/appstore/release-tag.sh" "$@"
