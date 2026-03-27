#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
exec "$ROOT_DIR/scripts/tooling/xcodecloud_post_clone.sh"
