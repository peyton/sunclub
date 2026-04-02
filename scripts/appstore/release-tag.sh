#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"

version="${VERSION:-${1:-}}"

fail() {
  printf 'release-tag: %s\n' "$1" >&2
  exit 1
}

[ -n "$version" ] || fail "usage: VERSION=1.2.3 $0"

case "$version" in
[0-9]*.[0-9]*.[0-9]*) ;;
*)
  fail "version must match X.Y.Z"
  ;;
esac

cd "$ROOT_DIR"

[ -z "$(git status --short)" ] || fail "working tree must be clean before tagging"

tag="v$version"

git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null &&
  fail "tag $tag already exists"

git tag -a "$tag" -m "Release $tag"
git push origin "$tag"

printf 'Created and pushed %s\n' "$tag"
