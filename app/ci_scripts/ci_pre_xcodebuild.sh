#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck disable=SC2139
alias xcodebuild="$ROOT_DIR/bin/mise exec -- tuist xcodebuild"
