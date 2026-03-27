#!/usr/bin/env bash
#
# bump-version.sh — Bump the marketing version in Project.swift.
#
# Usage:
#   ./scripts/appstore/bump-version.sh 1.0    # Set to 1.0
#   ./scripts/appstore/bump-version.sh 1.1    # Set to 1.1
#
set -euo pipefail

PROJECT_FILE="app/Project.swift"

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <version>"
  echo "  Example: $0 1.0"
  exit 1
fi

NEW_VERSION="$1"

if ! grep -q 'marketingVersion:' "$PROJECT_FILE"; then
  echo "Error: Could not find marketingVersion in $PROJECT_FILE"
  exit 1
fi

# Update the app target's marketing version (the first appSettings line)
sed -i '' "s/let appSettings = targetSettings(marketingVersion: \"[^\"]*\"/let appSettings = targetSettings(marketingVersion: \"$NEW_VERSION\"/" "$PROJECT_FILE"

echo "✓ Marketing version set to $NEW_VERSION in $PROJECT_FILE"
echo ""
echo "Remember to regenerate:"
echo "  just generate"
